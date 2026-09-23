/**
 * Longueur d'un texte libre, en POINTS DE CODE Unicode : c'est ce que
 * « N caractères au plus » veut dire dans les contrats qui s'en servent.
 *
 * Pourquoi cette unité, et pas une autre :
 *  - `string.length` compte les unités UTF-16 : un émoji simple y vaut deux,
 *    et « 280 caractères » refusait 141 émojis ;
 *  - `@MaxLength` (validator.js) compte une paire de substitution pour un,
 *    mais EFFACE les sélecteurs de variante (U+FE0E, U+FE0F) qui suivent un
 *    caractère : ni l'une ni l'autre des unités usuelles, et impossible à
 *    écrire à côté d'une constante sans l'expliquer ;
 *  - les graphèmes (ce que l'œil voit) n'ont pas de borne en stockage : un
 *    seul graphème peut porter des centaines de diacritiques empilés.
 * Le point de code est borné (au plus deux unités UTF-16 chacun), se calcule
 * pareil partout (`[...texte]` en JavaScript, `runes` en Dart), et c'est
 * l'unité de `maxLength` en JSON Schema, donc celle que Swagger annonce déjà.
 *
 * Conséquence à connaître : un émoji composé (drapeau, teinte de peau,
 * famille, ❤️ avec son sélecteur) compte pour plusieurs.
 */
export function codePointLength(text: string): number {
  return [...text].length;
}
