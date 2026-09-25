/// La base d'aliments : la table CIQUAL de l'Anses, servie par
/// `GET /nutrition/foods`.
///
/// Toutes les valeurs y sont données POUR 100 g. Une macro à `null` veut
/// dire « la table ne la donne pas », jamais zéro.
library;

/// Valeurs nutritionnelles pour 100 g d'un aliment.
class FoodPer100g {
  const FoodPer100g({
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  /// Toujours connue : un aliment sans énergie n'est pas importé.
  final double kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
}

/// Un aliment de la base, tel que la recherche le rend.
class Food {
  const Food({
    required this.code,
    required this.name,
    required this.shortName,
    required this.per100g,
    this.group,
  });

  /// `alim_code` CIQUAL : la clé à renvoyer dans la composition d'un repas.
  final int code;

  /// Nom officiel : « Poulet, filet, sans peau, cuit ».
  final String name;

  /// Le segment avant la première virgule : « Poulet ».
  final String shortName;

  /// Groupe CIQUAL (« viandes, œufs, poissons et assimilés »), `null` s'il
  /// n'est pas décrit.
  final String? group;
  final FoodPer100g per100g;

  FoodFamily get family => FoodFamily.fromGroup(group);
}

/// La mention que la licence de la table exige d'afficher près des valeurs
/// qui en viennent (Licence Ouverte Etalab 2.0 : réutilisation libre AVEC
/// mention de la source et de la date de sa mise à jour).
class FoodAttribution {
  const FoodAttribution({
    required this.attribution,
    required this.license,
    required this.url,
  });

  /// « Source : Anses, Table de composition nutritionnelle des aliments
  /// Ciqual ».
  final String attribution;
  final String license;
  final String url;
}

/// La mention, et la version de la table chargée côté serveur.
class FoodSource extends FoodAttribution {
  const FoodSource({
    required super.attribution,
    required super.license,
    required super.url,
    this.version,
  });

  /// « 2020-07-07 » ; `null` tant que la base est VIDE (pas encore
  /// importée) : l'écran le dit, et la saisie à la main reste possible.
  final String? version;

  bool get isEmpty => version == null;
}

/// Une recherche dans la base : les aliments trouvés, et la mention à
/// afficher là où l'on cherche.
typedef FoodSearchResult = ({List<Food> foods, FoodSource source});

/// La fiche d'un aliment, et la même mention.
typedef FoodDetail = ({Food food, FoodSource source});

/// La FAMILLE d'un aliment, déduite de son groupe CIQUAL : elle choisit la
/// vignette d'une ligne, la table n'ayant pas de photos.
///
/// Déduite par mots-clés plutôt que par égalité : le libellé d'un groupe est
/// du texte, qu'une nouvelle version de la table peut retoucher (« et
/// assimilés »). Un groupe inconnu tombe sur [other], jamais sur une famille
/// devinée.
enum FoodFamily {
  dishes,
  plants,
  cereals,
  proteins,
  dairy,
  drinks,
  frozen,
  sweets,
  fats,
  pantry,
  infant,
  other;

  static FoodFamily fromGroup(String? group) {
    final text = group?.toLowerCase().trim() ?? '';
    if (text.isEmpty) {
      return FoodFamily.other;
    }
    // L'ORDRE compte : « glaces et sorbets » avant « produits sucrés », et
    // « aliments infantiles » avant tout le reste (ses sous-groupes citent
    // les autres familles).
    for (final (keyword, family) in _keywords) {
      if (text.contains(keyword)) {
        return family;
      }
    }
    return FoodFamily.other;
  }

  static const List<(String, FoodFamily)> _keywords = [
    ('infantile', FoodFamily.infant),
    ('plats', FoodFamily.dishes),
    ('fruits', FoodFamily.plants),
    ('légumes', FoodFamily.plants),
    ('céréal', FoodFamily.cereals),
    ('viande', FoodFamily.proteins),
    ('poisson', FoodFamily.proteins),
    ('lait', FoodFamily.dairy),
    ('boisson', FoodFamily.drinks),
    ('glace', FoodFamily.frozen),
    ('sucr', FoodFamily.sweets),
    ('matières grasses', FoodFamily.fats),
    ('aides culinaires', FoodFamily.pantry),
  ];
}
