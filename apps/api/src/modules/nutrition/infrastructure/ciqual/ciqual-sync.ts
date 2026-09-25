import { createHash } from 'node:crypto';
import { type Food, type Prisma, type PrismaClient } from '@prisma/client';
import { type CiqualFood } from './ciqual-parse';

/**
 * Projeter une version de CIQUAL sur la table `Food` — idempotent, en UNE
 * transaction.
 *
 * Le calcul de ce qui change (`planFoodSync`) est pur et testé à part ;
 * l'écriture (`applyFoodSync`) ne fait qu'exécuter le plan. Rejouer la même
 * version ne crée ni ne modifie rien : tout est « inchangé ».
 *
 * Un aliment de la base absent de la nouvelle version (disparu, ou devenu
 * sans énergie connue) est RETIRÉ (`retiredAt`), jamais supprimé : des repas
 * le citent, et leur instantané doit rester lisible. Un aliment retiré qui
 * revient dans une version ultérieure est RÉACTIVÉ.
 */

type Existing = Pick<
  Food,
  | 'code'
  | 'name'
  | 'shortName'
  | 'searchKey'
  | 'groupCode'
  | 'groupName'
  | 'subgroupCode'
  | 'subgroupName'
  | 'kcalPer100g'
  | 'proteinPer100g'
  | 'carbsPer100g'
  | 'fatPer100g'
  | 'sourceVersion'
  | 'retiredAt'
>;

export interface FoodRow extends CiqualFood {
  readonly sourceVersion: string;
}

export interface FoodSyncPlan {
  readonly toCreate: readonly FoodRow[];
  /** Aliments actifs dont une valeur (ou la version) a changé. */
  readonly toUpdate: readonly FoodRow[];
  /** Aliments retirés qui reviennent dans cette version. */
  readonly toReactivate: readonly FoodRow[];
  readonly toRetire: readonly number[];
  readonly unchanged: number;
  /** Aliments en service AVANT cette version : la base du garde-fou des retraits. */
  readonly activeBefore: number;
}

function sameDecimal(a: Prisma.Decimal | null, b: Prisma.Decimal | null): boolean {
  return a === null || b === null ? a === b : a.equals(b);
}

function sameFood(existing: Existing, row: FoodRow): boolean {
  return (
    existing.name === row.name &&
    existing.shortName === row.shortName &&
    existing.searchKey === row.searchKey &&
    existing.groupCode === row.groupCode &&
    existing.groupName === row.groupName &&
    existing.subgroupCode === row.subgroupCode &&
    existing.subgroupName === row.subgroupName &&
    existing.sourceVersion === row.sourceVersion &&
    sameDecimal(existing.kcalPer100g, row.kcalPer100g) &&
    sameDecimal(existing.proteinPer100g, row.proteinPer100g) &&
    sameDecimal(existing.carbsPer100g, row.carbsPer100g) &&
    sameDecimal(existing.fatPer100g, row.fatPer100g)
  );
}

/** Ce que la nouvelle version change à la table (fonction pure). */
export function planFoodSync(
  existing: readonly Existing[],
  incoming: readonly CiqualFood[],
  sourceVersion: string,
): FoodSyncPlan {
  const byCode = new Map(existing.map((food) => [food.code, food]));
  const incomingCodes = new Set(incoming.map((food) => food.code));
  const toCreate: FoodRow[] = [];
  const toUpdate: FoodRow[] = [];
  const toReactivate: FoodRow[] = [];
  let unchanged = 0;
  for (const food of incoming) {
    const row: FoodRow = { ...food, sourceVersion };
    const stored = byCode.get(food.code);
    if (stored === undefined) {
      toCreate.push(row);
    } else if (stored.retiredAt !== null) {
      toReactivate.push(row);
    } else if (sameFood(stored, row)) {
      unchanged += 1;
    } else {
      toUpdate.push(row);
    }
  }
  const active = existing.filter((food) => food.retiredAt === null);
  const toRetire = active.filter((food) => !incomingCodes.has(food.code)).map((food) => food.code);
  return { toCreate, toUpdate, toReactivate, toRetire, unchanged, activeBefore: active.length };
}

/**
 * Au-delà d'un quart de la base retiré d'un coup, l'import s'arrête.
 *
 * Une nouvelle version de CIQUAL retire quelques aliments ; elle n'en retire
 * pas des centaines. Un tel plan dit presque toujours autre chose : un
 * dossier incomplet, un fichier `alim_*.xml` tronqué pile entre deux
 * aliments, la mauvaise distribution. Le retrait est réversible (un import
 * correct réactive), mais d'ici là la recherche ne trouverait plus rien et
 * les repas ne pourraient plus être composés. `--accepter-retraits` assume
 * le cas voulu, après une simulation (`--a-blanc`).
 */
export const MASS_RETIREMENT_SHARE = 0.25;

export function isMassRetirement(plan: FoodSyncPlan): boolean {
  return plan.activeBefore > 0 && plan.toRetire.length > plan.activeBefore * MASS_RETIREMENT_SHARE;
}

export class MassRetirementError extends Error {}

/**
 * Une clé de verrou consultatif propre à l'import, dérivée d'un nom comme
 * celles des ligues (`league-groups.ts`) : deux imports lancés en même temps
 * (deux terminaux, un déploiement et une main) se suivent au lieu de
 * s'entrelacer.
 */
const IMPORT_LOCK_KEY = createHash('sha256')
  .update('carlys:ciqual-import')
  .digest()
  .readBigInt64BE(0);

/** 3 200 lignes en une instruction dépasseraient la limite de paramètres. */
const CREATE_CHUNK = 500;

/** Assez large pour une nouvelle version entière réécrite ligne à ligne. */
const TRANSACTION_TIMEOUT_MS = 180_000;

function writable(row: FoodRow): Prisma.FoodCreateManyInput {
  return { ...row, retiredAt: null };
}

/**
 * Lit l'existant, calcule le plan et, sauf simulation, l'écrit — le tout
 * dans la même transaction : une erreur au milieu ne laisse RIEN d'écrit.
 */
export async function applyFoodSync(
  prisma: PrismaClient,
  incoming: readonly CiqualFood[],
  sourceVersion: string,
  options: {
    readonly dryRun: boolean;
    readonly allowMassRetirement?: boolean;
    readonly now?: Date;
  },
): Promise<FoodSyncPlan> {
  return prisma.$transaction(
    async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(${IMPORT_LOCK_KEY})`;
      const existing = await tx.food.findMany();
      const plan = planFoodSync(existing, incoming, sourceVersion);
      if (options.dryRun) {
        return plan;
      }
      if (isMassRetirement(plan) && options.allowMassRetirement !== true) {
        throw new MassRetirementError(
          `cette version retirerait ${plan.toRetire.length} aliments sur les ${plan.activeBefore} ` +
            'en service (plus d’un quart) : dossier incomplet ou mauvaise distribution ? ' +
            'Vérifie avec --a-blanc, puis relance avec --accepter-retraits si c’est voulu.',
        );
      }
      for (let start = 0; start < plan.toCreate.length; start += CREATE_CHUNK) {
        await tx.food.createMany({
          data: plan.toCreate.slice(start, start + CREATE_CHUNK).map(writable),
        });
      }
      for (const row of [...plan.toUpdate, ...plan.toReactivate]) {
        const { code, ...data } = writable(row);
        await tx.food.update({ where: { code }, data });
      }
      if (plan.toRetire.length > 0) {
        await tx.food.updateMany({
          where: { code: { in: [...plan.toRetire] } },
          data: { retiredAt: options.now ?? new Date() },
        });
      }
      return plan;
    },
    { timeout: TRANSACTION_TIMEOUT_MS, maxWait: 10_000 },
  );
}
