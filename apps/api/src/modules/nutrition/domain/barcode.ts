/**
 * Un code-barres de produit (GTIN) tel que la caméra ou la saisie le donne :
 * EAN-8, UPC-A (12), EAN-13 ou GTIN-14, rendu tel quel s'il est valide.
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
  return (10 - (sum % 10)) % 10 === Number(code[code.length - 1]) ? code : null;
}
