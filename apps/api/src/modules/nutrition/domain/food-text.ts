/**
 * Le texte d'un aliment : son nom court et sa clé de recherche.
 *
 * Fonctions pures, partagées par l'import CIQUAL (qui calcule la clé une
 * fois, à l'écriture) et par la recherche (qui normalise la saisie de la
 * même façon). Une seule définition : si les deux divergeaient, « Œuf »
 * tapé au clavier ne retrouverait plus « oeuf » stocké en base.
 */

/**
 * Les ligatures que la décomposition Unicode ne sépare PAS : « œ » et « æ »
 * sont des lettres à part entière pour Unicode, pas des ligatures de
 * compatibilité comme « ﬁ ». Sans cette table, « bœuf » deviendrait
 * « b uf » et ne se retrouverait ni par « boeuf » ni par « bœuf ».
 */
const LETTER_LIGATURES: Readonly<Record<string, string>> = {
  œ: 'oe',
  Œ: 'oe',
  æ: 'ae',
  Æ: 'ae',
  ß: 'ss',
};

/**
 * Minuscules, sans accents ni ligatures, toute ponctuation remplacée par une
 * espace, espaces resserrées : « Bœuf, haché 5% MG, cuit » devient
 * « boeuf hache 5 mg cuit ».
 *
 * NFKD plutôt que NFD : elle sépare aussi les ligatures typographiques
 * (« ﬁ ») et ramène les exposants à leur chiffre. Les signes restants
 * (« % », « / », « ° », apostrophes) deviennent des espaces : ce sont des
 * séparateurs de mots, pas des mots.
 *
 * Effet voulu côté recherche : la clé ne contient QUE `[a-z0-9 ]`, donc
 * aucun joker SQL (`%`, `_`, `\`) ne peut y survivre.
 */
export function normalizeFoodText(text: string): string {
  return text
    .replace(/[œŒæÆß]/g, (letter) => LETTER_LIGATURES[letter] ?? letter)
    .normalize('NFKD')
    .replace(/\p{M}+/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/**
 * Le nom court : le segment avant la première virgule, « Poulet » pour
 * « Poulet, filet, sans peau, cuit ». C'est la convention de nommage de
 * CIQUAL — l'aliment d'abord, ses précisions ensuite. Un nom sans virgule
 * est son propre nom court.
 */
export function shortFoodName(name: string): string {
  const head = name.split(',', 1)[0]?.trim() ?? '';
  return head.length > 0 ? head : name.trim();
}

/**
 * Les mots d'une recherche, normalisés et sans doublon, dans l'ordre de
 * saisie : le premier sert au classement (« commence par »).
 */
export function searchWords(query: string): string[] {
  const words = normalizeFoodText(query)
    .split(' ')
    .filter((word) => word.length > 0);
  return [...new Set(words)];
}
