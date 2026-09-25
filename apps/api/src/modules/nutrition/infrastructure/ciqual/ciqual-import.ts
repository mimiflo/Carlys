import { type PrismaClient } from '@prisma/client';
import { readCiqualDirectory } from './ciqual-files';
import { type CiqualIgnored, parseCiqual } from './ciqual-parse';
import { applyFoodSync, isMassRetirement } from './ciqual-sync';

/**
 * L'import d'une distribution CIQUAL, de bout en bout : lire le dossier,
 * interpréter les quatre fichiers, projeter sur la table `Food`.
 *
 * Appelé par la commande `dist/cli/ciqual-import` et par la suite e2e, qui
 * charge le jeu d'essai par ce même chemin. Tout ce qui peut échouer À LA
 * LECTURE échoue AVANT la transaction : un fichier absent, un constituant
 * introuvable ou une teneur illisible n'écrit rien du tout.
 */

export class CiqualImportError extends Error {}

export interface CiqualImportReport {
  readonly version: string;
  readonly dryRun: boolean;
  /** Enregistrements de `alim_*.xml` lus. */
  readonly read: number;
  readonly created: number;
  readonly updated: number;
  readonly reactivated: number;
  readonly unchanged: number;
  readonly retired: number;
  /** Aliments en service avant l'import. */
  readonly activeBefore: number;
  /** Vrai quand le plan retire plus d'un quart de la base (voir `isMassRetirement`). */
  readonly massRetirement: boolean;
  readonly ignored: readonly CiqualIgnored[];
  readonly warnings: readonly string[];
}

export async function importCiqualDirectory(
  prisma: PrismaClient,
  directory: string,
  options: {
    readonly version?: string;
    readonly dryRun?: boolean;
    readonly allowMassRetirement?: boolean;
  } = {},
): Promise<CiqualImportReport> {
  const { set, xml } = readCiqualDirectory(directory);
  const version = options.version ?? set.datedVersion;
  if (version === null) {
    throw new CiqualImportError(
      `impossible de dater ${set.files.alim} : précise la version avec --version.`,
    );
  }
  const parsed = parseCiqual(xml);
  // Aucun aliment importable : ce n'est pas une table vide, c'est une
  // distribution mal lue. L'écrire RETIRERAIT toute la base en place.
  if (parsed.foods.length === 0) {
    throw new CiqualImportError(
      `aucun aliment importable parmi ${parsed.read} lus : distribution incomplète ou mal lue, rien n’a été écrit.`,
    );
  }
  const dryRun = options.dryRun ?? false;
  const plan = await applyFoodSync(prisma, parsed.foods, version, {
    dryRun,
    allowMassRetirement: options.allowMassRetirement,
  });
  return {
    version,
    dryRun,
    read: parsed.read,
    created: plan.toCreate.length,
    updated: plan.toUpdate.length,
    reactivated: plan.toReactivate.length,
    unchanged: plan.unchanged,
    retired: plan.toRetire.length,
    activeBefore: plan.activeBefore,
    massRetirement: isMassRetirement(plan),
    ignored: parsed.ignored,
    warnings: set.warnings,
  };
}
