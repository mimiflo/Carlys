/**
 * `node dist/cli/meal-photos-sweep [--a-blanc] [--delai-minutes <n>]`
 *
 * Efface du bucket PRIVÉ les photos de repas ORPHELINES : les objets que
 * plus aucune ligne `MealPhoto` d'un repas vivant ne cite. C'est le filet
 * de toutes les suppressions de photo, qui effacent l'objet APRÈS la base et
 * journalisent l'échec au lieu de le lever (repas supprimé, photo retirée ou
 * remplacée, compte supprimé pendant que le stockage ne répondait pas).
 *
 * `--a-blanc` compte sans rien effacer. `--delai-minutes` règle le délai de
 * grâce (60 par défaut) : un objet plus jeune est épargné, il est peut-être
 * en train d'être enregistré.
 *
 * Même forme que `ciqual-import` : une commande de l'image de l'API, hors de
 * Nest. Rejouable à volonté. Sort en 1 si un effacement a échoué.
 */
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import { S3PrivateObjectStore } from '../infrastructure/storage/s3-private-object-store';
import {
  DEFAULT_SWEEP_GRACE_MS,
  type SweepReport,
  sweepOrphanMealPhotos,
} from '../modules/nutrition/application/meal-photo-sweep';
import { MealPhotoLedger } from '../modules/nutrition/infrastructure/meal-photo-ledger';

export class UsageError extends Error {}

export interface SweepArgs {
  readonly dryRun: boolean;
  readonly graceMs: number;
}

/** Lit les arguments (sans `node` ni le script). */
export function parseArgs(argv: readonly string[]): SweepArgs {
  let dryRun = false;
  let graceMs = DEFAULT_SWEEP_GRACE_MS;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index] ?? '';
    if (arg === '--a-blanc') {
      dryRun = true;
    } else if (arg === '--delai-minutes') {
      const value = Number(argv[index + 1]);
      if (!Number.isInteger(value) || value < 0) {
        throw new UsageError('--delai-minutes attend un nombre entier de minutes, 0 ou plus.');
      }
      graceMs = value * 60_000;
      index += 1;
    } else {
      throw new UsageError(`Argument inconnu : « ${arg} ».`);
    }
  }
  return { dryRun, graceMs };
}

function usage(): string {
  return [
    'Usage : node dist/cli/meal-photos-sweep [--a-blanc] [--delai-minutes <n>]',
    '  Efface du bucket privé les photos de repas que plus aucun repas ne cite.',
    '  --a-blanc        compte sans rien effacer.',
    '  --delai-minutes  épargne les objets plus jeunes (défaut : 60).',
  ].join('\n');
}

export function formatReport(report: SweepReport, dryRun: boolean, bucket: string): string {
  return [
    dryRun
      ? `Simulation (--a-blanc) : RIEN n’a été effacé. Bucket ${bucket}.`
      : `Balayage des photos de repas orphelines. Bucket ${bucket}.`,
    `  objets lus         : ${report.scanned}`,
    `  photos vivantes    : ${report.live}`,
    `  orphelins récents  : ${report.young} (épargnés, délai de grâce)`,
    `  orphelins          : ${report.orphans}`,
    `  effacés            : ${report.deleted}`,
    ...report.failures.map((failure) => `  ÉCHEC : ${failure}`),
    '',
  ].join('\n');
}

async function main(argv: readonly string[]): Promise<number> {
  let args: SweepArgs;
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
    const report = await sweepOrphanMealPhotos(store, new MealPhotoLedger(prisma), {
      now: new Date(),
      graceMs: args.graceMs,
      dryRun: args.dryRun,
    });
    process.stdout.write(formatReport(report, args.dryRun, store.bucket));
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
