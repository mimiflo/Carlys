import { searchWords } from './food-text';

/**
 * Ce que cherche le rapprochement d'un nom LIBRE, celui que le modèle de
 * vision donne à ce qu'il voit (« Haricots verts, cuits »), dans la table
 * CIQUAL (« Haricot vert, cuit »). ADR 0015.
 *
 * - [heads] : le mot ENTIER qui doit figurer dans l'aliment, essayé dans
 *   l'ordre. D'abord le premier nom (CIQUAL nomme l'aliment avant ses
 *   précisions), puis, faute de lui, les suivants ; jamais un chiffre, et un
 *   mot de préparation seulement s'il est seul (« Frites »).
 * - [terms] : chaque mot entier classe les candidats, tel quel ([exact]) ou
 *   accordé (1 point : « cuit » retrouve « cuites »). Tel quel, un mot vaut 2,
 *   sauf le NOM dont le pluriel ne dit rien (« Oeufs », « Crevettes ») : il
 *   ne pousse ni les « oeufs de lompe » ni le nem « aux crevettes ». « pâtes »,
 *   que le pluriel distingue de la « pâte sablée », garde ses 2 points ; « pois »
 *   ne trouve plus le poisson.
 * - [cooked] : le nom dit cuit, grillé, poêlé… ; une variante crue recule.
 *
 * Mesuré le 4 octobre 2026 sur la vraie table (12 repas, 40 aliments) : 27
 * retrouvés de la photo à l'aliment, contre 20 en retirant les mots de fin un
 * à un.
 */
export interface ClosestFoodQuery {
  readonly heads: readonly string[];
  readonly terms: readonly {
    readonly word: string;
    readonly base: string;
    /** Les points du mot retrouvé TEL QUEL (sa forme de base en vaut 1). */
    readonly exact: 1 | 2;
  }[];
  readonly cooked: boolean;
}

/** Six mots suffisent à nommer un aliment, et bornent la requête. */
const MAX_WORDS = 6;

/** Ils lient les mots sans rien dire de l'aliment. */
const LINK_WORDS = new Set([
  'a',
  'au',
  'aux',
  'avec',
  'd',
  'de',
  'des',
  'du',
  'en',
  'et',
  'l',
  'la',
  'le',
  'les',
  'ou',
  'sans',
  'un',
  'une',
]);

/** Ils disent que l'aliment est passé au feu. */
const COOKED_WORDS = new Set([
  'bouilli',
  'bouillie',
  'braise',
  'braisee',
  'cuit',
  'cuite',
  'frit',
  'frite',
  'grille',
  'grillee',
  'poele',
  'poelee',
  'roti',
  'rotie',
  'saute',
  'sautee',
  'vapeur',
]);

/** Ils disent la préparation ou la découpe : un aliment ne s'y nomme qu'à défaut d'autre mot. */
const PREPARATION_WORDS = new Set([
  ...COOKED_WORDS,
  'coupe',
  'coupee',
  'cru',
  'crue',
  'cube',
  'entier',
  'entiere',
  'frais',
  'fraiche',
  'hache',
  'hachee',
  'morceau',
  'nature',
  'rape',
  'rapee',
  'rondelle',
  'tranche',
]);

/** Leur pluriel change le sens : « pâtes » n'est pas « pâte ». */
const MEANING_PLURALS = new Set(['pates']);

/** « haricots » → « haricot », « bœufs » → « boeuf » ; « pois » et « riz » restent. */
export function baseFoodWord(word: string): string {
  return word.length > 4 && /[sx]$/.test(word) ? word.slice(0, -1) : word;
}

type Term = Pick<ClosestFoodQuery['terms'][number], 'word' | 'base'>;

/** « frais » a pour base « frai » : le mot ET sa base sont regardés. */
function among(set: Set<string>, term: Term): boolean {
  return set.has(term.word) || set.has(term.base);
}

/** Une tête nomme un aliment : des lettres, deux au moins (« 1 », « 2 » n'en sont pas). */
function canName(term: Term): boolean {
  return term.base.length >= 2 && /[a-z]/.test(term.base);
}

/** `null` : le nom ne porte aucun mot d'aliment (vide, ponctuation, liaisons, chiffres). */
export function closestFoodQuery(label: string): ClosestFoodQuery | null {
  const terms = searchWords(label)
    .filter((word) => !LINK_WORDS.has(word))
    .slice(0, MAX_WORDS)
    .map((word) => ({ word, base: baseFoodWord(word) }));
  const named = terms.filter(canName);
  // Les noms d'abord, dans l'ordre du libellé ; un mot de préparation ne sert
  // de tête que s'il est seul (« Frites »), jamais devant « jambon » dans
  // « Tranche de jambon ».
  const foods = named.filter((term) => !among(PREPARATION_WORDS, term));
  const heads = [...new Set((foods.length > 0 ? foods : named).map((term) => term.base))];
  const [noun] = heads;
  if (noun === undefined) return null;
  return {
    heads,
    terms: terms.map((term) => ({
      ...term,
      exact: term.base === noun && !MEANING_PLURALS.has(term.word) ? 1 : 2,
    })),
    cooked: terms.some((term) => among(COOKED_WORDS, term)),
  };
}
