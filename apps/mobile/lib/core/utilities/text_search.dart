/// CHERCHER UN PRÉNOM comme on le tape : sans majuscules ni accents.
///
/// « lea » doit trouver « Léa », « ELOISE » doit trouver « Éloïse ». La
/// recherche de la Communauté filtre des listes déjà chargées — jamais le
/// serveur, qui n'énumère personne —, et une recherche qui exigerait l'accent
/// exact ne trouverait pas la moitié des prénoms français.
library;

const Map<String, String> _plis = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
  'ç': 'c', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', //
  'ñ': 'n', //
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
  'ÿ': 'y', 'ý': 'y', //
  'œ': 'oe', 'æ': 'ae', //
};

/// [text] en minuscules, accents et ligatures repliés.
String foldForSearch(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_plis[char] ?? char);
  }
  return buffer.toString();
}

/// Vrai si [text] contient [query], à la casse et aux accents près. Une
/// requête vide ou blanche retient tout : effacer la recherche rend la liste.
bool matchesSearch(String text, String query) {
  final wanted = foldForSearch(query.trim());
  return wanted.isEmpty || foldForSearch(text).contains(wanted);
}
