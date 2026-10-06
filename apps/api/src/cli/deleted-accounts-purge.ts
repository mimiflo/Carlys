/**
 * `node dist/cli/deleted-accounts-purge [--a-blanc] [--delai-jours <n>] [--compte <uuid>]`
 * `node dist/cli/deleted-accounts-purge [--a-blanc] --compte-actif <uuid> --confirmer <adresse>`
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
 * `--compte-actif <uuid> --confirmer <adresse>` efface un compte ENCORE
 * ACTIF, sur demande écrite de la personne. Il passe d'abord par le MÊME
 * chemin que `DELETE /users/me` — abonnement Stripe résilié (refus si
 * Stripe ne l'a pas fait), retrait immédiat de la ligue, des défis et du fil
 * des autres —, audité `account.deleted_by_operator`, puis efface tout de
 * suite, comme `--compte`. `--confirmer` recopie l'adresse du compte : si
 * elle ne correspond pas, rien n'est fait. Avec `--a-blanc`, il dit ce qui
 * serait fait. Pour que le chemin soit LITTÉRALEMENT celui de la route,
 * cette voie démarre l'application (Nest) ; la purge quotidienne reste un
 * client Prisma nu.
 *
 * Même forme que `meal-photos-sweep` : une commande de l'image de l'API,
 * lancée chaque jour par la supervision (scripts/server/_purge_comptes.sh).
 * Rejouable à volonté. Sort en 1 si un compte n'a pas pu être effacé, en 2
 * sur un argument invalide, un `--compte` refusé ou une confirmation qui ne
 * correspond pas.
 */
import { type INestApplicationContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import { type PrivateObjectStore } from '../infrastructure/storage/private-object-store';
import { S3PrivateObjectStore } from '../infrastructure/storage/s3-private-object-store';
import {
  DEAD_SESSION_RETENTION_DAYS,
  DEFAULT_PURGE_DELAY_DAYS,
  type DeletedAccountsLedger,
  ORPHAN_PAYMENT_EVENT_RETENTION_DAYS,
  type PurgeReport,
  purgeDeletedAccounts,
} from '../modules/users/application/deleted-accounts-purge';
import { PrismaDeletedAccountsLedger } from '../modules/users/infrastructure/deleted-accounts-ledger';
import {
  type ActiveAccountRequest,
  type CliOutput,
  deleteActiveAccount,
  withApplication,
} from './active-account-erasure';
import { readArgs, runCli, UsageError } from './run-cli';

export { UsageError };

export interface PurgeArgs {
  readonly dryRun: boolean;
  readonly delayDays: number;
  readonly accountId?: string;
  readonly activeAccount?: ActiveAccountRequest;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ADRESSE = /^[^\s@]+@[^\s@]+$/;

/** Lit les arguments (sans `node` ni le script). */
const DELAI = '--delai-jours attend un nombre entier de jours, 1 ou plus.';
const COMPTE = '--compte attend l’identifiant (UUID) du compte à effacer.';
const COMPTE_ACTIF = '--compte-actif attend l’identifiant (UUID) du compte à effacer.';
const CONFIRMER = '--confirmer attend l’adresse e-mail du compte, recopiée.';

export function parseArgs(argv: readonly string[]): PurgeArgs {
  const { values } = readArgs(
    argv,
    {
      'a-blanc': { type: 'boolean' },
      'delai-jours': { type: 'string' },
      compte: { type: 'string' },
      'compte-actif': { type: 'string' },
      confirmer: { type: 'string' },
    },
    {
      attentes: {
        'delai-jours': DELAI,
        compte: COMPTE,
        'compte-actif': COMPTE_ACTIF,
        confirmer: CONFIRMER,
      },
    },
  );
  const dryRun = values['a-blanc'] ?? false;
  const delayDays =
    values['delai-jours'] === undefined ? DEFAULT_PURGE_DELAY_DAYS : Number(values['delai-jours']);
  if (
    (values['delai-jours'] !== undefined && !/^\d+$/.test(values['delai-jours'])) ||
    delayDays < 1
  ) {
    throw new UsageError(DELAI);
  }
  const accountId = values.compte;
  if (accountId !== undefined && !UUID.test(accountId)) throw new UsageError(COMPTE);
  const activeId = values['compte-actif'];
  if (activeId !== undefined && !UUID.test(activeId)) throw new UsageError(COMPTE_ACTIF);
  const confirmEmail = values.confirmer?.trim();
  if (confirmEmail !== undefined && !ADRESSE.test(confirmEmail)) throw new UsageError(CONFIRMER);
  if ((activeId === undefined) !== (confirmEmail === undefined)) {
    throw new UsageError('--compte-actif et --confirmer vont ensemble : l’un exige l’autre.');
  }
  if (activeId !== undefined && accountId !== undefined) {
    throw new UsageError('--compte (déjà supprimé) et --compte-actif s’excluent.');
  }
  return {
    dryRun,
    delayDays,
    ...(accountId === undefined ? {} : { accountId }),
    ...(activeId === undefined || confirmEmail === undefined
      ? {}
      : { activeAccount: { id: activeId, confirmEmail } }),
  };
}

function usage(): string {
  return [
    'Usage : node dist/cli/deleted-accounts-purge [--a-blanc] [--delai-jours <n>] [--compte <uuid>]',
    '  Efface définitivement les comptes supprimés depuis plus de n jours.',
    '  --a-blanc      compte sans rien effacer.',
    `  --delai-jours  délai de conservation (défaut : ${DEFAULT_PURGE_DELAY_DAYS}).`,
    '  --compte       efface tout de suite CE compte supprimé, délai ignoré.',
    '',
    '       node dist/cli/deleted-accounts-purge [--a-blanc] --compte-actif <uuid> --confirmer <adresse>',
    '  Efface un compte ENCORE ACTIF sur demande écrite : supprimé comme par',
    '  DELETE /users/me (Stripe résilié, communauté quittée), audité, puis effacé.',
    '  --confirmer    l’adresse e-mail du compte, recopiée : sinon, rien n’est fait.',
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
    ...(args.accountId === undefined
      ? [
          `  paiements orphelins effacés (plus de ${ORPHAN_PAYMENT_EVENT_RETENTION_DAYS} jours) : ${report.paymentEventsErased}`,
          `  sessions closes effacées (plus de ${DEAD_SESSION_RETENTION_DAYS} jours) : ${report.sessionsErased.sessions}`,
          `  jetons de renouvellement échus effacés : ${report.sessionsErased.refreshTokens}`,
        ]
      : []),
    ...report.failures.map((failure) => `  ÉCHEC : ${failure}`),
    '',
  ].join('\n');
}

/** Ce que la commande touche : la base, le bucket, la console, l'application. */
export interface PurgeDeps {
  readonly ledger: DeletedAccountsLedger;
  readonly store: PrivateObjectStore;
  readonly io: CliOutput;
  /** L'application entière, le temps de `--compte-actif` ([withApplication]). */
  readonly withApp: (
    work: (app: INestApplicationContext) => Promise<number | 'deleted'>,
  ) => Promise<number | 'deleted'>;
}

/**
 * La commande, arguments lus : rend son code de sortie. `main` et l'e2e
 * appellent CETTE fonction, pour que l'enchaînement éprouvé soit celui qui
 * tourne, et non une copie écrite dans le test.
 */
export async function runPurge(args: PurgeArgs, deps: PurgeDeps): Promise<number> {
  let accountId = args.accountId;
  const activeAccount = args.activeAccount;
  if (activeAccount !== undefined) {
    const issue = await deps.withApp((app) =>
      deleteActiveAccount(app, activeAccount, args.dryRun, deps.io),
    );
    if (issue !== 'deleted') {
      return issue;
    }
    // Supprimé : l'effacement immédiat est celui de `--compte`, tel quel.
    accountId = activeAccount.id;
  }
  const report = await purgeDeletedAccounts(deps.ledger, deps.store, {
    now: new Date(),
    delayDays: args.delayDays,
    dryRun: args.dryRun,
    ...(accountId === undefined ? {} : { accountId }),
  });
  if (report.refused !== null) {
    deps.io.err(`${report.refused}\n`);
    return 2;
  }
  deps.io.out(formatReport(report, { ...args, ...(accountId === undefined ? {} : { accountId }) }));
  return report.failures.length > 0 ? 1 : 0;
}

async function main(argv: readonly string[]): Promise<number> {
  let args: PurgeArgs;
  try {
    args = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`${(error as Error).message}\n\n${usage()}\n`);
    return 2;
  }

  // Configuration invalide : runCli la dit en « Échec : … », code 1.
  const config = new AppConfigService(new ConfigService<Env, true>(validateEnv(process.env)));
  const prisma = new PrismaClient({ datasourceUrl: config.databaseUrl });
  const store = new S3PrivateObjectStore(config);
  try {
    return await runPurge(args, {
      ledger: new PrismaDeletedAccountsLedger(prisma),
      store,
      io: { out: (text) => process.stdout.write(text), err: (text) => process.stderr.write(text) },
      withApp: withApplication,
    });
  } catch (error) {
    process.stderr.write(`Échec : ${(error as Error).message}\n`);
    return 1;
  } finally {
    store.onModuleDestroy();
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  runCli(main);
}
