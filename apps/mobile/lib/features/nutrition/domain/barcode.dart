/// Un code-barres de produit (GTIN) : EAN-8, UPC-A (12), EAN-13 ou GTIN-14,
/// chiffre de contrôle juste. Le même contrôle que l'API : une lecture ratée
/// (un chiffre faux) n'est même pas envoyée.
bool isProductBarcode(String raw) {
  final code = raw.trim();
  if (!RegExp(r'^(?:\d{8}|\d{12,14})$').hasMatch(code)) return false;
  var sum = 0;
  // Pondération GTIN : en partant du chiffre voisin du contrôle, 3, 1, 3…
  for (var i = code.length - 2, weight = 3; i >= 0; i--, weight = 4 - weight) {
    sum += int.parse(code[i]) * weight;
  }
  return (10 - sum % 10) % 10 == int.parse(code[code.length - 1]);
}
