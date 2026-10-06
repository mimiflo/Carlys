/**
 * La recherche d'exercices du coach, telle que le modèle l'écrit (outil
 * `search_exercises`), traduite vers ce que le catalogue range.
 *
 * Le modèle écrit « pecs », « pectoral », « haltères », ou glisse le muscle
 * dans les mots du NOM (« pectoraux » ne figure dans aucun nom d'exercice).
 * Chaque écart vidait la recherche, et le coach concluait qu'il n'existait
 * aucun exercice pour les pectoraux (1er octobre 2026). Ici :
 *
 * - un groupe ou un matériel se reconnaît par son slug, son nom, sans
 *   accents, par un début de mot non ambigu, ou par un mot de salle ;
 * - si le nom cherché tel quel ne donne rien, un mot de la recherche qui
 *   désigne un groupe ou un matériel devient ce filtre ;
 * - un nom inconnu ou ambigu est REFUSÉ avec la liste des valeurs : le
 *   modèle corrige au tour suivant, au lieu de conclure sur une liste vide.
 */

interface CatalogEntry {
  slug: string;
  name: string;
}

export interface ExerciseSearch {
  search?: string;
  muscleGroupSlug?: string;
  equipmentSlug?: string;
}

/** Les mots de salle qu'aucun début de slug ne retrouve. */
const SLANG: Record<string, string> = {
  pec: 'pectoraux',
  pecs: 'pectoraux',
  abdo: 'abdominaux',
  abdos: 'abdominaux',
  ischios: 'ischio-jambiers',
  quadris: 'quadriceps',
};

/** Sans accents ni majuscules : « Développé » et « developpe » se rejoignent. */
export const fold = (text: string) =>
  text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();

const normalize = (text: string) => fold(text).trim().replace(/\s+/g, '-');

/** Le slug désigné par [term] ; `null` s'il n'y en a pas, ou plusieurs. */
function resolve(term: string, entries: readonly CatalogEntry[]): string | null {
  const wanted = SLANG[normalize(term)] ?? normalize(term);
  const exact = entries.find((entry) => entry.slug === wanted || normalize(entry.name) === wanted);
  if (exact !== undefined) return exact.slug;
  // « barres » → barre, « elastiques » → elastique : le plus long slug par
  // lequel le mot commence.
  const longer = entries
    .filter((entry) => entry.slug.length >= 4 && wanted.startsWith(entry.slug))
    .sort((a, b) => b.slug.length - a.slug.length)[0];
  if (longer !== undefined) return longer.slug;
  // « pectoral » → pectoraux. Cinq lettres au moins : « row » ou « dip »
  // désigneraient n'importe quoi (rouleau, disque).
  if (wanted.length < 5) return null;
  const close = entries.filter((entry) => entry.slug.startsWith(wanted.slice(0, -1)));
  return close.length === 1 ? (close[0]?.slug ?? null) : null;
}

function required(term: string, entries: readonly CatalogEntry[], what: string): string {
  const slug = resolve(term, entries);
  if (slug === null) {
    throw new Error(
      `${what} inconnu « ${term} ». Valeurs possibles : ` +
        `${entries.map((entry) => entry.slug).join(', ')}.`,
    );
  }
  return slug;
}

/** Texte non vide, rogné ; tout le reste rend `undefined`. */
export const text = (value: unknown) =>
  typeof value === 'string' && value.trim() !== '' ? value.trim() : undefined;

type Catalog = { muscleGroups: readonly CatalogEntry[]; equipment: readonly CatalogEntry[] };

/**
 * Premier essai : les champs de groupe et de matériel traduits, et les mots
 * du nom laissés ENTIERS. Le dépôt cherche le nom d'un seul tenant : en
 * retirer « mollets » ou « barre » ferait manquer « Extensions mollets
 * debout » ou « Rowing barre buste penché », cherchés par leur nom exact.
 */
export function exerciseSearchFilters(
  input: Record<string, unknown>,
  catalog: Catalog,
): ExerciseSearch {
  const search = text(input.search);
  const muscleTerm = text(input.muscleGroupSlug);
  const gearTerm = text(input.equipmentSlug);
  return {
    ...(search === undefined ? {} : { search }),
    ...(muscleTerm === undefined
      ? {}
      : { muscleGroupSlug: required(muscleTerm, catalog.muscleGroups, 'Groupe musculaire') }),
    ...(gearTerm === undefined
      ? {}
      : { equipmentSlug: required(gearTerm, catalog.equipment, 'Matériel') }),
  };
}

/**
 * Second essai, quand le premier ne trouve rien : un mot de la recherche
 * qui nomme un groupe ou un matériel (« pectoraux », « pecs », « haltères »)
 * devient ce filtre. `null` s'il n'y avait rien à en tirer.
 */
export function filtersFromSearch(
  filters: ExerciseSearch,
  catalog: Catalog,
): ExerciseSearch | null {
  let { muscleGroupSlug, equipmentSlug } = filters;
  const words: string[] = [];
  for (const word of filters.search?.split(/\s+/) ?? []) {
    const muscle = muscleGroupSlug === undefined ? resolve(word, catalog.muscleGroups) : null;
    const gear =
      muscle === null && equipmentSlug === undefined ? resolve(word, catalog.equipment) : null;
    if (muscle !== null) muscleGroupSlug = muscle;
    else if (gear !== null) equipmentSlug = gear;
    else words.push(word);
  }
  if (muscleGroupSlug === filters.muscleGroupSlug && equipmentSlug === filters.equipmentSlug) {
    return null;
  }
  return {
    ...(words.length === 0 ? {} : { search: words.join(' ') }),
    ...(muscleGroupSlug === undefined ? {} : { muscleGroupSlug }),
    ...(equipmentSlug === undefined ? {} : { equipmentSlug }),
  };
}

/** Ce que les deux fonctions suivantes lisent d'un exercice. */
interface Named {
  name: string;
  primaryMuscleGroup: { slug: string } | null;
}

/**
 * Les exercices dont le nom contient CHAQUE mot cherché, sans accents ni
 * majuscules, dans n'importe quel ordre. Le dépôt cherche le nom d'un seul
 * tenant et accents compris : « developpe couche » y manquait 93 des 190
 * exercices du catalogue (balayage du 1er octobre 2026).
 */
export function matchByName<T extends Named>(items: readonly T[], search: string): T[] {
  const words = fold(search)
    .split(/\s+/)
    .filter((word) => word !== '');
  return items.filter((item) => {
    const name = fold(item.name);
    return words.every((word) => name.includes(word));
  });
}

/**
 * Le filtre de groupe retient aussi les muscles SECONDAIRES (des burpees
 * pour les pectoraux, des squats pour les fessiers) : seuls restent les
 * exercices dont c'est le muscle principal, s'il y en a. Sinon chaque
 * groupe des jambes rendait les mêmes squats et fentes, et le contexte du
 * modèle payait chaque doublon (2 octobre 2026).
 */
export function primaryOnly<T extends Named>(items: readonly T[], muscle: string | undefined): T[] {
  const primary = items.filter((item) => item.primaryMuscleGroup?.slug === muscle);
  return primary.length > 0 ? primary : [...items];
}
