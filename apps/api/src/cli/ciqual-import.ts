/**
 * `node dist/cli/ciqual-import <dossier> [--version <libellé>] [--a-blanc] [--accepter-retraits]`
 *
 * Charge la base d'aliments depuis la distribution XML OFFICIELLE de la
 * table CIQUAL de l'Anses (Licence Ouverte Etalab 2.0) : le dossier qui
 * contient `alim_*.xml`, `alim_grp_*.xml`, `compo_*.xml` et `const_*.xml`,
 * tels que téléchargés (voir `docs/product/nutrition.md`, « Base
 * d'aliments »).
 *
 * Même forme que `catalog-seed` : une commande de l'image de l'API, qui écrit
 * directement en base. Idempotente — la même version rejouée ne change rien —
 * et transactionnelle : un fichier ou un constituant introuvable, une teneur
 * illisible font échouer l'import AVANT toute écriture, et une erreur
 * pendant l'écriture n'en laisse aucune trace. Jamais une base à moitié
 * chargée.
 *
 * `--a-blanc` lit tout, calcule ce qui changerait, l'affiche, et n'écrit
 * rien : c'est le premier geste à faire sur un nouveau fichier.
 *
 * Une version qui retirerait plus d'un quart des aliments en service est
 * refusée (dossier incomplet ? mauvaise distribution ?) ;
 * `--accepter-retraits` l'assume, après simulation.
 *
 * Pas branchée dans le déploiement automatique : contrairement au catalogue
 * d'exercices, la table n'est pas livrée avec le code. Voir la section
 * « Base d'aliments » de `docs/product/nutrition.md` pour l'endroit où la
 * brancher.
 */
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { AppConfigService } from '../config/app-config.service';
import { type Env, validateEnv } from '../config/env.schema';
import { CIQUAL_ATTRIBUTION } from '../modules/nutrition/domain/ciqual-source';
import {
  type CiqualImportReport,
  importCiqualDirectory,
} from '../modules/nutrition/infrastructure/ciqual/ciqual-import';

export class UsageError extends Error {}

export interface CiqualImportArgs {
  readonly directory: string;
  readonly version?: string;
  readonly dryRun: boolean;
  readonly allowMassRetirement: boolean;
}

/** Lit les arguments (sans `node` ni le script). */
export function parseArgs(argv: readonly string[]): CiqualImportArgs {
  let directory: string | undefined;
  let version: string | undefined;
  let dryRun = false;
  let allowMassRetirement = false;
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index] ?? '';
    if (arg === '--a-blanc') {
      dryRun = true;
    } else if (arg === '--accepter-retraits') {
      allowMassRetirement = true;
    } else if (arg === '--version') {
      const value = argv[index + 1]?.trim() ?? '';
      if (value === '' || value.startsWith('--')) {
        throw new UsageError('--version attend un libellé, par exemple « 2020-07-07 ».');
      }
      version = value;
      index += 1;
    } else if (arg.startsWith('--')) {
      throw new UsageError(`Option inconnue : « ${arg} ».`);
    } else if (directory === undefined) {
      directory = arg;
    } else {
      throw new UsageError(`Un seul dossier attendu, reçu aussi « ${arg} ».`);
    }
  }
  if (directory === undefined) {
    throw new UsageError('Dossier de la distribution CIQUAL manquant.');
  }
  return { directory, version, dryRun, allowMassRetirement };
}

function usage(): string {
  return [
    'Usage : node dist/cli/ciqual-import <dossier> [--version <libellé>] [--a-blanc] [--accepter-retraits]',
    '  Charge (ou met à jour) la base d’aliments depuis la distribution XML',
    '  officielle CIQUAL : alim_*.xml, alim_grp_*.xml, compo_*.xml, const_*.xml.',
    '  --version  libellé de la version (défaut : la date du nom de alim_*.xml).',
    '  --a-blanc  lit et compte tout, n’écrit rien.',
    '  --accepter-retraits  autorise une version qui retire plus d’un quart des aliments.',
  ].join('\n');
}

/** Les ignorés, regroupés par raison, avec quelques exemples nommés. */
function ignoredLines(report: CiqualImportReport): string[] {
  const byReason = new Map<string, string[]>();
  for (const food of report.ignored) {
    byReason.set(food.reason, [...(byReason.get(food.reason) ?? []), `${food.code} ${food.name}`]);
  }
  return [...byReason.entries()].map(([reason, foods]) => {
    const examples = foods.slice(0, 3).join(' ; ');
    return `      ${reason} : ${foods.length} (ex. ${examples}${foods.length > 3 ? ' ; …' : ''})`;
  });
}

export function formatReport(report: CiqualImportReport): string {
  return [
    report.dryRun
      ? `Simulation (--a-blanc) : RIEN n’a été écrit. Version ${report.version}.`
      : `Table CIQUAL chargée. Version ${report.version}.`,
    `  aliments lus : ${report.read}`,
    `  créés        : ${report.created}`,
    `  mis à jour   : ${report.updated}`,
    `  réactivés    : ${report.reactivated}`,
    `  inchangés    : ${report.unchanged}`,
    `  retirés      : ${report.retired} (sortis de la recherche, gardés pour les repas qui les citent)`,
    `  ignorés      : ${report.ignored.length}`,
    ...ignoredLines(report),
    ...report.warnings.map((warning) => `  attention : ${warning}`),
    ...(report.massRetirement
      ? [
          `  attention : ${report.retired} retraits sur ${report.activeBefore} aliments en service, ` +
            (report.dryRun
              ? 'plus d’un quart : l’import réel exigera --accepter-retraits.'
              : 'plus d’un quart, acceptés par --accepter-retraits.'),
        ]
      : []),
    `  mention à afficher : ${CIQUAL_ATTRIBUTION} (version ${report.version}).`,
    '',
  ].join('\n');
}

async function main(argv: readonly string[]): Promise<number> {
  let args: CiqualImportArgs;
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
  try {
    const report = await importCiqualDirectory(prisma, args.directory, {
      version: args.version,
      dryRun: args.dryRun,
      allowMassRetirement: args.allowMassRetirement,
    });
    process.stdout.write(formatReport(report));
    return 0;
  } catch (error) {
    process.stderr.write(`Échec, rien n’a été écrit : ${(error as Error).message}\n`);
    return 1;
  } finally {
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
