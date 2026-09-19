import { type MealEntry as MealEntryContract } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type MealEntry, type MealQuantityUnit } from '@prisma/client';
import { MealsRepository } from '../infrastructure/meals.repository';

/**
 * L'amplitude maximale d'une demande de journal.
 *
 * Un an couvre largement ce que les écrans demandent — le jour courant, la
 * semaine, au plus un mois pour une courbe — tout en refusant la demande
 * dégénérée : deux dates éloignées d'une décennie, servies en une fois. Le
 * plafond de LIGNES (`MealsRepository.HARD_LIMIT`) ferme l'autre moitié de la
 * porte : une année chargée reste bornée en volume.
 */
const MAX_RANGE_DAYS = 366;
const MAX_RANGE_MS = MAX_RANGE_DAYS * 24 * 3_600_000;

function present(meal: MealEntry): MealEntryContract {
  return {
    id: meal.id,
    name: meal.name,
    kcal: meal.kcal,
    // `Decimal` ne traverse pas JSON : sérialisé tel quel, il devient une
    // CHAÎNE côté client, que `z.number()` refuserait. La conversion est
    // sans perte — deux décimales tiennent très en deçà de la précision d'un
    // double, et la colonne n'en accepte pas plus.
    quantity: meal.quantity === null ? null : meal.quantity.toNumber(),
    quantityUnit: meal.quantityUnit,
    proteinG: meal.proteinG,
    carbsG: meal.carbsG,
    fatG: meal.fatG,
    eatenAt: meal.eatenAt.toISOString(),
  };
}

/**
 * Une quantité et son unité vont ENSEMBLE, dans les deux sens.
 *
 * « 250 » sans unité ne dit rien — grammes ? millilitres ? pièces ? — et
 * « en grammes » sans nombre ne dit rien non plus. L'affichage n'a alors que
 * deux choix, inventer l'autre moitié ou taire la première : mieux vaut
 * refuser la saisie que stocker une phrase qu'on ne saura pas finir.
 */
function assertPairedQuantity(quantity: number | null, unit: MealQuantityUnit | null): void {
  if ((quantity === null) !== (unit === null)) {
    throw new BadRequestException(
      'La quantité et son unité vont ensemble : donne les deux ou aucune.',
    );
  }
}

/**
 * Ce qu'une correction peut porter.
 *
 * `undefined` et `null` ne disent PAS la même chose : le premier veut dire
 * « n'y touche pas », le second « efface ». Seuls les champs qui peuvent
 * légitimement redevenir inconnus acceptent `null` — un repas garde toujours
 * un nom, des calories et une heure.
 */
export interface MealPatch {
  name?: string;
  kcal?: number;
  quantity?: number | null;
  quantityUnit?: MealQuantityUnit | null;
  proteinG?: number | null;
  carbsG?: number | null;
  fatG?: number | null;
  eatenAt?: Date;
}

/** La quantité stockée, ramenée au nombre que le reste du service manipule. */
function quantityOf(meal: MealEntry): number | null {
  return meal.quantity === null ? null : meal.quantity.toNumber();
}

/**
 * Le fragment reçu traduit en écriture Prisma — les champs absents restent
 * absents, ce qui est exactement ce qui les laisse intacts en base.
 */
function toUpdateData(patch: MealPatch): Prisma.MealEntryUpdateInput {
  const data: Prisma.MealEntryUpdateInput = {};
  if (patch.name !== undefined) data.name = patch.name;
  if (patch.kcal !== undefined) data.kcal = patch.kcal;
  if (patch.quantity !== undefined) data.quantity = patch.quantity;
  if (patch.quantityUnit !== undefined) data.quantityUnit = patch.quantityUnit;
  if (patch.proteinG !== undefined) data.proteinG = patch.proteinG;
  if (patch.carbsG !== undefined) data.carbsG = patch.carbsG;
  if (patch.fatG !== undefined) data.fatG = patch.fatG;
  if (patch.eatenAt !== undefined) data.eatenAt = patch.eatenAt;
  return data;
}

/**
 * Journal alimentaire — la moitié RÉELLE du « consommé / objectif ».
 *
 * Mêmes règles que les séances : identifiant généré sur l'appareil (création
 * idempotente, rejouable), suppression douce idempotente, et des INSTANTS
 * UTC — le découpage en journées appartient au client, qui connaît son
 * fuseau ; le serveur ne devine jamais où commence « aujourd'hui ».
 */
@Injectable()
export class MealsService {
  constructor(private readonly meals: MealsRepository) {}

  /** Création idempotente : rejouer la même écriture rend la même entrée. */
  async add(
    userId: string,
    input: {
      id: string;
      name: string;
      kcal: number;
      quantity: number | null;
      quantityUnit: MealQuantityUnit | null;
      proteinG: number | null;
      carbsG: number | null;
      fatG: number | null;
      eatenAt: Date;
    },
  ): Promise<MealEntryContract> {
    assertPairedQuantity(input.quantity, input.quantityUnit);
    await this.meals.create({ userId, ...input });
    const stored = await this.meals.findById(input.id);
    if (stored === null || stored.userId !== userId) {
      // L'identifiant existe déjà chez QUELQU'UN D'AUTRE : collision réelle.
      throw new ConflictException('Identifiant de repas déjà utilisé.');
    }
    return present(stored);
  }

  /**
   * Repas entre deux instants (bornes du jour local, calculées au client).
   *
   * La plage est BORNÉE, et la requête plafonnée. C'était la seule collection
   * du dépôt sans plafond : toutes les autres portent un `limit` validé
   * (`@Max(MAX_PAGE_SIZE)` pour les séances et les modèles, `@Max(365)` pour
   * les mesures corporelles, `@Max(200)` pour l'audit). Ici, deux dates
   * suffisaient à demander des années de journal en une requête, et le dépôt
   * servait tout. L'écran, lui, ne demande jamais qu'un jour ou une semaine.
   */
  async list(userId: string, from: Date, to: Date): Promise<MealEntryContract[]> {
    if (to.getTime() <= from.getTime()) {
      throw new BadRequestException('La borne haute doit suivre la borne basse.');
    }
    if (to.getTime() - from.getTime() > MAX_RANGE_MS) {
      throw new BadRequestException(
        `La plage demandée dépasse ${MAX_RANGE_DAYS} jours — découper la demande.`,
      );
    }
    const meals = await this.meals.listBetween(userId, from, to);
    return meals.map(present);
  }

  /**
   * Correction d'un repas déjà journalisé.
   *
   * On se trompe en tapant — une calorie de trop, le bon plat la veille, une
   * portion mal estimée — et la seule réparation offerte jusqu'ici était de
   * supprimer puis ressaisir : le repas disparaissait du total, puis
   * revenait, sous un AUTRE identifiant. Corriger sur place garde l'entrée,
   * son identifiant et sa place dans le journal.
   *
   * Un champ ABSENT reste tel quel, un champ à `null` efface ce qu'on croyait
   * savoir : corriger les calories ne doit pas emporter les macros.
   */
  async update(userId: string, id: string, patch: MealPatch): Promise<MealEntryContract> {
    if (Object.values(patch).every((value) => value === undefined)) {
      throw new BadRequestException('Rien à corriger : donne au moins un champ.');
    }
    const stored = await this.meals.findById(id);
    // Le repas d'autrui est INTROUVABLE, jamais « interdit » : un 403
    // confirmerait que cet identifiant existe.
    if (stored === null || stored.userId !== userId || stored.deletedAt !== null) {
      throw new NotFoundException('Repas introuvable.');
    }
    // La cohérence se juge sur l'état APRÈS correction, pas sur le seul
    // fragment reçu : effacer l'unité sans toucher au nombre laisserait
    // « 250 » tout seul, ce qu'aucun écran ne sait afficher.
    assertPairedQuantity(
      patch.quantity !== undefined ? patch.quantity : quantityOf(stored),
      patch.quantityUnit !== undefined ? patch.quantityUnit : stored.quantityUnit,
    );
    const updated = await this.meals.update(id, toUpdateData(patch));
    return present(updated);
  }

  /** Idempotent : supprimer un repas déjà supprimé ou inconnu aboutit. */
  async remove(userId: string, id: string): Promise<void> {
    const meal = await this.meals.findById(id);
    if (meal === null || meal.deletedAt !== null) {
      return;
    }
    if (meal.userId !== userId) {
      // Même réponse qu'un 404 : ne pas révéler l'existence d'autrui.
      throw new NotFoundException('Repas introuvable.');
    }
    await this.meals.softDelete(id);
  }
}
