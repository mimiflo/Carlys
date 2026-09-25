import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Trouver et décoder les quatre fichiers d'une distribution XML CIQUAL.
 *
 * La distribution officielle est un dossier de fichiers datés :
 * `alim_2020_07_07.xml` (aliments), `alim_grp_2020_07_07.xml` (groupes),
 * `compo_2020_07_07.xml` (teneurs) et `const_2020_07_07.xml` (constituants),
 * plus `sources_*.xml` dont l'import n'a pas besoin. Chaque fichier doit
 * être trouvé EXACTEMENT une fois : absent, l'import s'arrête ; en double
 * (deux versions mélangées dans le même dossier), il s'arrête aussi, plutôt
 * que de choisir au hasard.
 */

export class CiqualFilesError extends Error {}

export type CiqualFileKind = 'alim' | 'alimGrp' | 'compo' | 'const';

/** Le préfixe de chaque fichier ; `alim_` ne doit pas avaler `alim_grp_`. */
const PATTERNS: Readonly<Record<CiqualFileKind, RegExp>> = {
  alim: /^alim_(?!grp_)(.*)\.xml$/i,
  alimGrp: /^alim_grp_(.*)\.xml$/i,
  compo: /^compo_(.*)\.xml$/i,
  const: /^const_(.*)\.xml$/i,
};

const LABELS: Readonly<Record<CiqualFileKind, string>> = {
  alim: 'alim_*.xml (aliments)',
  alimGrp: 'alim_grp_*.xml (groupes)',
  compo: 'compo_*.xml (teneurs)',
  const: 'const_*.xml (constituants)',
};

export interface CiqualFileSet {
  /** Nom de chaque fichier retenu, relatif au dossier. */
  readonly files: Readonly<Record<CiqualFileKind, string>>;
  /** Le suffixe daté de `alim_*.xml`, mis en forme (« 2020-07-07 »), ou `null`. */
  readonly datedVersion: string | null;
  /** Suffixes discordants entre les quatre fichiers — signalés, pas bloquants. */
  readonly warnings: readonly string[];
}

/** « 2020_07_07 » devient « 2020-07-07 » ; tout autre suffixe reste tel quel. */
function versionOf(suffix: string): string | null {
  const dated = /^(\d{4})_(\d{2})_(\d{2})$/.exec(suffix);
  if (dated !== null) {
    return `${dated[1]}-${dated[2]}-${dated[3]}`;
  }
  return suffix.length > 0 ? suffix : null;
}

/** Choisit les quatre fichiers dans la liste d'un dossier (fonction pure). */
export function locateCiqualFiles(entries: readonly string[]): CiqualFileSet {
  const files = {} as Record<CiqualFileKind, string>;
  const suffixes = {} as Record<CiqualFileKind, string>;
  const problems: string[] = [];
  for (const kind of Object.keys(PATTERNS) as CiqualFileKind[]) {
    const matches = entries.filter((entry) => PATTERNS[kind].test(entry));
    const [only] = matches;
    if (matches.length === 1 && only !== undefined) {
      files[kind] = only;
      suffixes[kind] = PATTERNS[kind].exec(only)?.[1] ?? '';
    } else if (matches.length === 0) {
      problems.push(`fichier introuvable : ${LABELS[kind]}`);
    } else {
      problems.push(`plusieurs fichiers ${LABELS[kind]} : ${matches.join(', ')}`);
    }
  }
  if (problems.length > 0) {
    throw new CiqualFilesError(problems.join(' ; ') + '.');
  }
  const reference = suffixes.alim;
  const warnings = (Object.keys(suffixes) as CiqualFileKind[])
    .filter((kind) => suffixes[kind] !== reference)
    .map(
      (kind) =>
        `${files[kind]} ne porte pas la date de ${files.alim} : vérifie qu’il vient de la même version.`,
    );
  return { files, datedVersion: versionOf(reference), warnings };
}

/**
 * Décode un fichier selon l'encodage que DÉCLARE son prologue XML, et en
 * windows-1252 s'il n'en déclare pas : c'est l'encodage de la distribution
 * CIQUAL. Lire ce fichier en UTF-8 transformerait « Règlement » en
 * « R\uFFFDglement », et la résolution des constituants par leur nom
 * échouerait — bruyamment, mais pour une mauvaise raison.
 */
export function decodeCiqualXml(bytes: Uint8Array): string {
  const head = Buffer.from(bytes.subarray(0, 200)).toString('latin1');
  const declared = /<\?xml[^>]*encoding\s*=\s*["']([A-Za-z0-9._-]+)["']/i.exec(head)?.[1];
  try {
    return new TextDecoder(declared ?? 'windows-1252', { fatal: true }).decode(bytes);
  } catch (error) {
    throw new CiqualFilesError(
      `décodage impossible (encodage ${declared ?? 'windows-1252'}) : ${(error as Error).message}`,
    );
  }
}

/** Lit et décode les quatre fichiers d'un dossier. */
export function readCiqualDirectory(directory: string): {
  readonly set: CiqualFileSet;
  readonly xml: Readonly<Record<CiqualFileKind, string>>;
} {
  let entries: string[];
  try {
    entries = readdirSync(directory);
  } catch (error) {
    throw new CiqualFilesError(`dossier illisible « ${directory} » : ${(error as Error).message}`);
  }
  const set = locateCiqualFiles(entries);
  const xml = {} as Record<CiqualFileKind, string>;
  for (const kind of Object.keys(set.files) as CiqualFileKind[]) {
    const name = set.files[kind];
    try {
      xml[kind] = decodeCiqualXml(readFileSync(join(directory, name)));
    } catch (error) {
      throw new CiqualFilesError(`${name} : ${(error as Error).message}`);
    }
  }
  return { set, xml };
}
