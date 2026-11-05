/**
 * Un code-barres de produit (GTIN) tel que la caméra ou la saisie le donne :
 * EAN-8, UPC-A (12), EAN-13 ou GTIN-14. Un UPC-A est rendu en EAN-13 (le
 * même code, précédé d'un 0) : `036000291452` et `0036000291452` désignent un
 * même produit, et ne font qu'une clé de cache.
 *
 * Le chiffre de contrôle est VÉRIFIÉ : une lecture ratée (un chiffre faux)
 * ne part pas chez Open Food Facts chercher le produit d'un autre. `null` :
 * ce n'est pas un code de produit.
 */
export function normalizeBarcode(raw: string): string | null {
  const code = raw.trim();
  if (!/^(?:\d{8}|\d{12,14})$/.test(code)) return null;
  // Pondération GTIN : en partant du chiffre voisin du contrôle, 3, 1, 3…
  let sum = 0;
  for (let i = code.length - 2, weight = 3; i >= 0; i--, weight = 4 - weight) {
    sum += Number(code[i]) * weight;
  }
  if ((10 - (sum % 10)) % 10 !== Number(code[code.length - 1])) return null;
  // Le 0 de tête ne change pas le chiffre de contrôle (son poids est nul).
  return code.length === 12 ? `0${code}` : code;
}
