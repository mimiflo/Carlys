/**
 * Texte libre FACULTATIF tel qu'il s'écrit en base : découpé des blancs
 * autour, et `null` quand il ne reste rien.
 *
 * « Rien écrit », « trois espaces » et « champ absent » disent la même chose
 * — pas de texte —, et une seule valeur doit la porter : sinon l'écran
 * affiche une bulle vide pour un message de trois espaces, et une requête qui
 * cherche « sans précisions » manque les chaînes vides.
 *
 * Née dans la modération (les précisions d'un signalement) ; le mot du
 * créateur d'un défi entre amis suit la même règle, d'où sa place ici plutôt
 * qu'une seconde copie qui divergerait.
 */
export function blankToNull(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed === undefined || trimmed === '' ? null : trimmed;
}
