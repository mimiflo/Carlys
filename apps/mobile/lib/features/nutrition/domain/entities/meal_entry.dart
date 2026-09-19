/// Une entrée du journal alimentaire — ce que l'utilisateur dit avoir mangé.
///
/// Sortie de `nutrition.dart`, qui rassemblait le métabolisme ET le journal :
/// deux sujets, deux durées de vie, un seul fichier qui grossissait à chaque
/// champ ajouté d'un côté comme de l'autre.
library;

/// L'unité dans laquelle une quantité se dit.
///
/// Quatre, parce que c'est ce qu'on lit sur un emballage ou dans une
/// assiette. Le libellé est au SINGULIER : « 1 portion » se lit bien, et
/// [MealQuantityUnit.spell] accorde le pluriel quand il le faut.
enum MealQuantityUnit {
  gram('GRAM', 'g', 'g', 'grammes'),
  milliliter('MILLILITER', 'ml', 'ml', 'millilitres'),
  portion('PORTION', 'portion', 'portions', 'portions'),
  piece('PIECE', 'pièce', 'pièces', 'pièces');

  const MealQuantityUnit(this.apiValue, this.label, this._plural, this.pick);

  final String apiValue;

  /// Ce qui s'écrit après le nombre : « 250 g », « 1 portion ».
  final String label;
  final String _plural;

  /// Ce qui s'écrit dans le CHOISISSEUR, où il n'y a aucun nombre à côté
  /// pour donner le sens : une pastille « g » isolée devient un jeton rond
  /// d'un seul caractère, qu'on ne lit plus comme une unité.
  final String pick;

  /// `null` pour une valeur absente OU inconnue — jamais une unité devinée.
  /// Rabattre l'inconnu sur « g » écrirait « 2 g » là où le serveur dit
  /// « 2 pièces », c'est-à-dire une quantité FAUSSE plutôt qu'absente.
  static MealQuantityUnit? fromApi(String? value) {
    for (final unit in MealQuantityUnit.values) {
      if (unit.apiValue == value) {
        return unit;
      }
    }
    return null;
  }

  /// La quantité écrite en toutes lettres : « 250 g », « 1,5 portion »,
  /// « 2 pièces ».
  ///
  /// Deux règles de français, et non une : le pluriel commence à DEUX — une
  /// portion et demie reste « 1,5 portion » — et la virgule est la
  /// séparatrice décimale. Les zéros de fin ne s'écrivent pas : « 1,50 »
  /// laisse croire à une précision au centième que personne n'a saisie.
  String spell(double quantity) {
    final nombre = quantity == quantity.roundToDouble()
        ? quantity.round().toString()
        : quantity
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceAll('.', ',');
    return '$nombre ${quantity >= 2 ? _plural : label}';
  }
}

/// Ce qu'une correction dit d'un repas : TOUT ce qui se saisit.
///
/// La route accepte un fragment — un champ absent reste tel quel — mais le
/// formulaire, lui, montre l'entrée ENTIÈRE et rend ce que la personne a
/// sous les yeux au moment où elle valide. Vider la case « Protéines » veut
/// alors dire « on ne sait plus », et cela doit s'écrire : n'envoyer que les
/// champs modifiés laisserait cet effacement sans effet.
///
/// D'où un objet COMPLET plutôt qu'un fragment : les champs qui ne peuvent
/// pas redevenir inconnus (nom, calories, heure) sont requis, les autres
/// sont explicitement nuls quand la case est vide.
class MealCorrection {
  const MealCorrection({
    required this.name,
    required this.kcal,
    required this.eatenAt,
    this.quantity,
    this.quantityUnit,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  final String name;
  final int kcal;
  final DateTime eatenAt;
  final double? quantity;
  final MealQuantityUnit? quantityUnit;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
}

/// Ce qui a été mangé : un nom, des calories, une heure, et ce qu'on sait du
/// reste.
///
/// C'est la moitié RÉELLE du « consommé / objectif » de l'accueil.
/// L'identifiant est un UUID généré sur l'appareil (création idempotente).
class MealEntry {
  const MealEntry({
    required this.id,
    required this.name,
    required this.kcal,
    required this.eatenAt,
    this.quantity,
    this.quantityUnit,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  final String id;
  final String name;

  /// Les calories RÉELLEMENT consommées pour ce repas — jamais « par
  /// unité » : la quantité ci-dessous ne les multiplie pas.
  final int kcal;

  /// La quantité mangée et son unité, toutes deux facultatives et liées :
  /// elles valent `null` ensemble, ou elles sont renseignées ensemble. Une
  /// quantité sans unité ne dit rien — « 250 », mais de quoi ?
  ///
  /// PUREMENT DESCRIPTIVE : elle ne multiplie NI [kcal] NI les macros. Le
  /// serveur applique la même règle, et les bornes de saisie (10 000 kcal,
  /// 1 000 g par macro) sont des bornes de REPAS, pas d'unité.
  final double? quantity;
  final MealQuantityUnit? quantityUnit;

  /// Les trois macros, toutes facultatives et INDÉPENDANTES : `null` veut
  /// dire « on ne sait pas », jamais « zéro ». L'écran affiche quatre macros
  /// CIBLES et n'en journalisait que deux — la comparaison consommé /
  /// objectif était impossible sur les deux tiers de ce qu'il montrait.
  final int? proteinG;
  final int? carbsG;
  final int? fatG;

  /// Instant de consommation, UTC — l'affichage est localisé.
  final DateTime eatenAt;

  /// La quantité prête à lire, ou `null` quand l'entrée n'en porte pas.
  ///
  /// La paire se vérifie ICI plutôt qu'à chaque affichage : un serveur d'une
  /// version future pourrait servir une unité que cette application ignore,
  /// et [MealQuantityUnit.fromApi] rendrait alors `null` sur une quantité
  /// bien présente. Écrire le nombre tout seul serait pire que se taire.
  String? get spelledQuantity {
    final valeur = quantity;
    final unite = quantityUnit;
    if (valeur == null || unite == null) {
      return null;
    }
    return unite.spell(valeur);
  }
}
