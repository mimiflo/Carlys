/**
 * La mention de source de la base d'aliments.
 *
 * La table CIQUAL de l'Anses est publiée sous Licence Ouverte Etalab 2.0 :
 * réutilisation libre, y compris commerciale, À CONDITION de mentionner la
 * paternité de l'information — sa source et la date de sa dernière mise à
 * jour. Ce n'est pas une politesse : sans la mention, la réutilisation sort
 * de la licence. La recherche d'aliments la renvoie donc dans `meta`, avec la
 * version chargée, pour que l'écran l'affiche à côté des valeurs ; les routes
 * de repas aussi, dès qu'un repas porte des aliments de la table, et chaque
 * ligne y dit la version dont viennent SES valeurs.
 */
export const CIQUAL_ATTRIBUTION =
  'Source : Anses, Table de composition nutritionnelle des aliments Ciqual';
export const CIQUAL_LICENSE = 'Licence Ouverte Etalab 2.0';
export const CIQUAL_URL = 'https://ciqual.anses.fr/';

/** La mention complète à afficher, sans la version, propre à chaque réponse. */
export function ciqualAttribution(): { attribution: string; license: string; url: string } {
  return { attribution: CIQUAL_ATTRIBUTION, license: CIQUAL_LICENSE, url: CIQUAL_URL };
}
