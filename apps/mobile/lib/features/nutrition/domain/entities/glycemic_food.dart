/// Le tableau des index glycémiques : contenu ÉDITORIAL embarqué, comme les
/// recettes. Les valeurs sont MESURÉES, reprises telles quelles d'une table
/// publiée ([glycemicIndexSource]) ; aucune n'est estimée par Carlys.
library;

/// La table dont viennent toutes les valeurs, citée sur la page.
const String glycemicIndexSource =
    'Atkinson FS, Foster-Powell K, Brand-Miller JC. International Tables of '
    'Glycemic Index and Glycemic Load Values: 2008. Diabetes Care '
    '2008;31(12):2281-2283. doi:10.2337/dc08-1239. Table 1, moyenne ± '
    'erreur standard, glucose = 100.';

/// Les familles d'aliments, dans l'ordre de la table source.
enum GlycemicCategory {
  breadsCereals('Pains et céréales'),
  breakfastCereals('Petit-déjeuner', 'Céréales du petit-déjeuner'),
  fruits('Fruits'),
  vegetables('Légumes'),
  dairy('Laitiers', 'Produits laitiers et alternatives'),
  legumes('Légumineuses'),
  snacks('Snacks'),
  sugars('Sucres');

  const GlycemicCategory(this.label, [this._title]);

  /// Court : la pastille du filtre.
  final String label;
  final String? _title;

  /// Complet : le titre de la section.
  String get title => _title ?? label;
}

/// Les deux renvois de la table source.
enum GlycemicMark {
  lowGiVarieties('*', 'Des variétés à IG bas existent aussi.'),
  allDataAverage('†', 'Moyenne de toutes les données publiées.');

  const GlycemicMark(this.symbol, this.meaning);

  final String symbol;
  final String meaning;
}

/// Bas (≤ 55), moyen (56 à 69) ou élevé (≥ 70) : le classement d'usage de
/// la table source.
enum GlycemicLevel {
  low('bas'),
  medium('moyen'),
  high('élevé');

  const GlycemicLevel(this.label);

  final String label;

  static GlycemicLevel of(int gi) => gi <= 55
      ? low
      : gi < 70
      ? medium
      : high;
}

/// Un aliment de la table.
class GlycemicFood {
  const GlycemicFood({
    required this.name,
    required this.category,
    required this.gi,
    required this.sem,
    this.mark,
  });

  final String name;
  final GlycemicCategory category;

  /// La moyenne mesurée, glucose = 100.
  final int gi;

  /// L'erreur standard de cette moyenne (le « ± »).
  final int sem;
  final GlycemicMark? mark;

  GlycemicLevel get level => GlycemicLevel.of(gi);

  /// Ce que lit le lecteur d'écran : « Pomme crue, IG 36, bas ».
  String get spoken {
    final note = mark == null ? '' : ' ${mark!.meaning}';
    return '$name, IG $gi, ${level.label}.$note';
  }
}
