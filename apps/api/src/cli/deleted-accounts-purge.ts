/**
 * `node dist/cli/deleted-accounts-purge [--a-blanc] [--delai-jours <n>] [--compte <uuid>]`
 *
 * EFFACE DÉFINITIVEMENT les comptes supprimés depuis plus de `n` jours
 * (30 par défaut) : leurs lignes en base, par cascade tout ce qui s'y
 * rattache, et leurs photos privées. Voir `purgeDeletedAccounts`.
 *
 * `--a-blanc` compte sans rien effacer. `--compte <uuid>` efface TOUT DE
 * SUITE ce compte précis, délai ignoré — l'effacement immédiat qu'une
 * personne peut demander par écrit ; il doit déjà être supprimé (statut
 * DELETED), un compte actif est refusé.
 *
 * Même forme que `meal-photos-sweep` : une commande de l'image de l'API,
 * hors de Nest, lancée chaque jour par la supervision
 * (scripts/server/_purge_comptes.sh). Rejouable à volonté. Sort en 1 si un
 * compte n'a pas pu être effacé, en 2 sur un argument invalide ou un
 * `--compte` refusé.
 */
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import { S3PrivateObjectStore } from '../infrastructure/storage/s3-private-object-store';
import {
  DEFAULT_PURGE_DELAY_DAYS,
  type PurgeReport,
  purgeDeletedAccounts,
} from '../modules/users/application/deleted-accounts-purge';
import { PrismaDeletedAccountsLedger } from '../modules/users/infrastructure/deleted-accounts-ledger';

export class UsageError extends Error {}

export interface PurgeArgs {
  readonly dryRun: boolean;
  readonly delayDays: number;
  readonly accountId?: string;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Lit les arguments (sans `node` ni le script). */
export function parseArgs(argv: readonly string[]): PurgeArgs {
  let dryRun = false;
  let delayDays = DEFAULT_PURGE_DELAY_DAYS;
  let accountId: string | undefined;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index] ?? '';
    if (arg === '--a-blanc') {
      dryRun = true;
    } else if (arg === '--delai-jours') {
      const value = Number(argv[index + 1]);
      if (!Number.isInteger(value) || value < 1) {
        throw new UsageError('--delai-jours attend un nombre entier de jours, 1 ou plus.');
      }
      delayDays = value;
      index += 1;
    } else if (arg === '--compte') {
      const value = argv[index + 1] ?? '';
      if (!UUID.test(value)) {
        throw new UsageError('--compte attend l’identifiant (UUID) du compte à effacer.');
      }
      accountId = value;
      index += 1;
    } else {
      throw new UsageError(`Argument inconnu : « ${arg} ».`);
    }
  }
  return { dryRun, delayDays, ...(accountId === undefined ? {} : { accountId }) };
}

function usage(): string {
  return [
    'Usage : node dist/cli/deleted-accounts-purge [--a-blanc] [--delai-jours <n>] [--compte <uuid>]',
    '  Efface définitivement les comptes supprimés depuis plus de n jours.',
    '  --a-blanc      compte sans rien effacer.',
    `  --delai-jours  délai de conservation (défaut : ${DEFAULT_PURGE_DELAY_DAYS}).`,
    '  --compte       efface tout de suite CE compte supprimé, délai ignoré.',
  ].join('\n');
}

export function formatReport(report: PurgeReport, args: PurgeArgs): string {
  const portee =
    args.accountId === undefined
      ? `comptes supprimés depuis plus de ${args.delayDays} jours`
      : `compte ${args.accountId}, effacement immédiat`;
  return [
    args.dryRun
      ? `Simulation (--a-blanc) : RIEN n’a été effacé. Portée : ${portee}.`
      : `Purge des comptes supprimés. Portée : ${portee}.`,
    `  comptes éligibles  : ${report.eligible}`,
    `  comptes effacés    : ${report.erased}`,
    `  photos effacées    : ${report.objectsDeleted}`,
    ...report.failures.map((failure) => `  ÉCHEC : ${failure}`),
    '',
  ].join('\n');
}

async function main(argv: readonly string[]): Promise<number> {
  let args: PurgeArgs;
  try {
    args = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`${(error as Error).message}\n\n${usage()}\n`);
    return 2;
  }

  let config: AppConfigService;
  try {
    const env: Env = validateEnv(process.env);
    config = new AppConfigService(new ConfigService<Env, true>(env));
  } catch (error) {
    process.stderr.write(`Échec : ${(error as Error).message}\n`);
    return 1;
  }
  const prisma = new PrismaClient({ datasourceUrl: config.databaseUrl });
  const store = new S3PrivateObjectStore(config);
  try {
    const report = await purgeDeletedAccounts(new PrismaDeletedAccountsLedger(prisma), store, {
      now: new Date(),
      delayDays: args.delayDays,
      dryRun: args.dryRun,
      ...(args.accountId === undefined ? {} : { accountId: args.accountId }),
    });
    if (report.refused !== null) {
      process.stderr.write(`${report.refused}\n`);
      return 2;
    }
    process.stdout.write(formatReport(report, args));
    return report.failures.length > 0 ? 1 : 0;
  } catch (error) {
    process.stderr.write(`Échec : ${(error as Error).message}\n`);
    return 1;
  } finally {
    store.onModuleDestroy();
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main(process.argv.slice(2))
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error: unknown) => {
      process.stderr.write(`Échec : ${(error as Error).message}\n`);
      process.exitCode = 1;
    });
}
