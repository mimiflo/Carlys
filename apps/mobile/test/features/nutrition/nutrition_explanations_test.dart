@TestOn('vm')
library;

import 'dart:io';

import 'package:carlys_mobile/core/explanations/explanation.dart';
import 'package:carlys_mobile/features/nutrition/domain/nutrition_explanations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/explanation_catalogue.dart';

/// Le calculateur du serveur : la SOURCE des nombres que les explications
/// citent. Chemin relatif à `apps/mobile`, d'où les tests s'exécutent.
final File _calculateur = File(
  '../api/src/modules/nutrition/application/metabolism.calculator.ts',
);

/// Le catalogue lui-même, lu comme un TEXTE : c'est le seul moyen, sans
/// réflexion, de savoir si une explication déclarée a été oubliée dans
/// `toutes`.
final File _catalogue = File(
  'lib/features/nutrition/domain/nutrition_explanations.dart',
);

/// Un nombre TypeScript tel qu'un francophone le lit : `1.375` → « 1,375 »,
/// `2.0` → « 2 ».
String _enFrancais(double valeur) {
  // `(1 - 0.85) * 100` vaut 14,999999999999998 en binaire : sans cet
  // arrondi, le test chercherait ce nombre-là dans un texte français.
  final propre = (valeur * 1000).round() / 1000;
  final entier = propre == propre.roundToDouble();
  return (entier ? propre.toInt().toString() : propre.toString()).replaceAll(
    '.',
    ',',
  );
}

/// Le corps d'une table `const NOM: Record<...> = { ... }`.
String _bloc(String source, String nom) {
  final trouve = RegExp('const $nom[^=]*= \\{([^}]*)\\}').firstMatch(source);
  expect(
    trouve,
    isNotNull,
    reason:
        'La table $nom a disparu du calculateur serveur. Les explications de '
        'MetricExplanations citent ses valeurs : relis-les avant de changer '
        'ce test.',
  );
  return trouve!.group(1)!;
}

double _valeur(String bloc, String cle, {required String dans}) {
  final trouve = RegExp('$cle:\\s*([0-9.]+)').firstMatch(bloc);
  expect(
    trouve,
    isNotNull,
    reason: 'La clé $cle a disparu de $dans côté serveur.',
  );
  return double.parse(trouve!.group(1)!);
}

/// Échoue en NOMMANT le chiffre qui a bougé — une explication qui ment est
/// pire qu'une absence d'explication.
void _cite(Explanation explication, String attendu, String quoi) {
  // Comparaison insensible à la casse : « un quart » est écrit « Un quart »
  // quand il ouvre la phrase, et la majuscule n'est pas le sujet du test.
  expect(
    explication.douCaSort.toLowerCase(),
    contains(attendu.toLowerCase()),
    reason:
        'Le serveur applique désormais « $attendu » pour $quoi, mais '
        'l’explication « ${explication.titre} » dit encore autre chose. '
        'Corrige le texte, pas ce test.',
  );
}

void main() {
  late String serveur;

  setUpAll(() {
    expect(
      _calculateur.existsSync(),
      isTrue,
      reason:
          'Le calculateur serveur est introuvable depuis apps/mobile : '
          '${_calculateur.path}',
    );
    serveur = _calculateur.readAsStringSync();
  });

  verifierCatalogue(
    nom: 'nutrition',
    source: _catalogue,
    toutes: NutritionExplanations.toutes,
  );

  group('les chiffres cités sont ceux que le serveur applique', () {
    test('facteurs d’activité — dépense énergétique', () {
      final bloc = _bloc(serveur, 'ACTIVITY_FACTORS');
      for (final niveau in const [
        'SEDENTARY',
        'LIGHT',
        'MODERATE',
        'ACTIVE',
        'VERY_ACTIVE',
      ]) {
        final facteur = _valeur(bloc, niveau, dans: 'ACTIVITY_FACTORS');
        _cite(
          NutritionExplanations.depenseEnergetique,
          _enFrancais(facteur),
          'le niveau $niveau',
        );
      }
    });

    test('formule de Mifflin-St Jeor — métabolisme de base', () {
      final formule = RegExp(
        r'const bmr =\s*([0-9.]+) \* weightKg \+ ([0-9.]+) \* heightCm '
        r'- ([0-9.]+) \* ageYears \+ \(sex === .MALE. \? ([0-9.]+) : '
        r'-([0-9.]+)\)',
      ).firstMatch(serveur);
      expect(
        formule,
        isNotNull,
        reason:
            'La formule du métabolisme de base n’est plus reconnaissable '
            'dans le calculateur serveur. Elle est RECOPIÉE en toutes '
            'lettres dans l’explication « Métabolisme de base » : relis-la '
            'avant de toucher à ce test.',
      );

      final poids = double.parse(formule!.group(1)!);
      final taille = double.parse(formule.group(2)!);
      final age = double.parse(formule.group(3)!);
      final homme = double.parse(formule.group(4)!);
      final femme = double.parse(formule.group(5)!);

      final explication = NutritionExplanations.metabolismeDeBase;
      _cite(explication, '${_enFrancais(poids)} ×', 'le poids');
      _cite(explication, '${_enFrancais(taille)} ×', 'la taille');
      _cite(explication, '${_enFrancais(age)} ×', 'l’âge');
      _cite(explication, '+${_enFrancais(homme)}', 'la constante masculine');
      _cite(explication, _enFrancais(femme), 'la constante féminine');
    });

    test('ajustement par objectif — cible calorique', () {
      final bloc = _bloc(serveur, 'GOAL_FACTORS');
      final perte = _valeur(bloc, 'LOSE_WEIGHT', dans: 'GOAL_FACTORS');
      final prise = _valeur(bloc, 'GAIN_MUSCLE', dans: 'GOAL_FACTORS');

      final explication = NutritionExplanations.caloriesCibles;
      _cite(
        explication,
        '${_enFrancais((1 - perte) * 100)} %',
        'le déficit de perte de gras',
      );
      _cite(
        explication,
        '${_enFrancais((prise - 1) * 100)} %',
        'le surplus de prise de muscle',
      );
    });

    test('plancher de sécurité — les deux seuils, par sexe', () {
      final bloc = _bloc(serveur, 'TARGET_KCAL_FLOOR');
      for (final sexe in const ['FEMALE', 'MALE']) {
        final plancher = _valeur(bloc, sexe, dans: 'TARGET_KCAL_FLOOR');
        // Cité DEUX fois, et c'est voulu : l'explication de l'objectif dit
        // qu'un plancher existe, celle du plancher dit pourquoi. Laisser
        // l'une des deux vieillir suffirait à faire mentir l'écran.
        _cite(
          NutritionExplanations.caloriesCibles,
          _enFrancais(plancher),
          'le plancher $sexe',
        );
        _cite(
          NutritionExplanations.plancherCalorique,
          _enFrancais(plancher),
          'le plancher $sexe',
        );
      }
    });

    test('le plancher s’applique AVANT les macros', () {
      // Si `fatG` se remettait à lire la cible d'avant plancher, l'écran
      // afficherait des macros qui ne totalisent pas la cible affichée.
      expect(
        serveur,
        contains('const target = Math.max(floor, ajuste);'),
        reason:
            'La cible n’est plus relevée au plancher avant le calcul des '
            'macros. L’explication « ${NutritionExplanations.plancherCalorique.titre} » '
            'affirme que c’est le plancher qui s’affiche : relis-la.',
      );
    });

    test('protéines — grammes par kilo', () {
      final bloc = _bloc(serveur, 'PROTEIN_PER_KG');
      final explication = NutritionExplanations.proteines;
      for (final objectif in const ['LOSE_WEIGHT', 'MAINTAIN', 'GAIN_MUSCLE']) {
        final parKilo = _valeur(bloc, objectif, dans: 'PROTEIN_PER_KG');
        _cite(explication, _enFrancais(parKilo), 'l’objectif $objectif');
      }
    });

    test('lipides — part des calories, en toutes lettres', () {
      final trouve = RegExp(r'const FAT_RATIO = ([0-9.]+)').firstMatch(serveur);
      expect(trouve, isNotNull, reason: 'FAT_RATIO a disparu du serveur.');
      final part = double.parse(trouve!.group(1)!);

      // L'explication écrit la part en FRANÇAIS (« un quart »), pas en
      // décimal : la table dit comment chaque valeur se lit. Une valeur
      // absente fait échouer ici, et c'est voulu — il faut alors écrire la
      // nouvelle formulation, pas la deviner.
      // `const` impossible : une clé `double` n'a pas d'égalité primitive.
      final enToutesLettres = <double, String>{
        0.2: 'un cinquième',
        0.25: 'un quart',
        0.3: 'trois dixièmes',
        0.35: 'plus d’un tiers',
      };
      final attendu = enToutesLettres[part];
      expect(
        attendu,
        isNotNull,
        reason:
            'La part des lipides est passée à $part : personne ne sait '
            'encore comment l’écrire en français dans l’explication '
            '« Lipides ». Ajoute la formulation, puis le texte.',
      );
      _cite(NutritionExplanations.lipides, attendu!, 'la part des lipides');
    });

    test('densités énergétiques — lipides et glucides', () {
      expect(
        serveur,
        contains('/ 9'),
        reason: 'Le serveur ne divise plus les lipides par 9 kcal/g.',
      );
      _cite(NutritionExplanations.lipides, '9 kcal par gramme', 'les lipides');
      _cite(
        NutritionExplanations.glucides,
        '4 kcal par gramme',
        'les glucides',
      );
    });

    test('hydratation — millilitres par kilo', () {
      final trouve = RegExp(
        r'waterMl: Math\.round\(([0-9.]+) \* weightKg\)',
      ).firstMatch(serveur);
      expect(
        trouve,
        isNotNull,
        reason: 'Le calcul de l’eau a changé de forme.',
      );
      _cite(
        NutritionExplanations.eau,
        '${_enFrancais(double.parse(trouve!.group(1)!))} millilitres',
        'l’hydratation',
      );
    });

    test('seuils d’IMC — ceux de l’OMS, tels que le serveur les code', () {
      final seuils = RegExp(
        r'if \(bmi < ([0-9.]+)\)',
      ).allMatches(serveur).map((m) => double.parse(m.group(1)!)).toList();
      expect(
        seuils,
        hasLength(3),
        reason:
            'Le serveur ne classe plus l’IMC en quatre tranches : '
            'l’explication « IMC » les énumère une par une.',
      );
      for (final seuil in seuils) {
        _cite(NutritionExplanations.imc, _enFrancais(seuil), 'un seuil d’IMC');
      }
    });
  });

  group('la donnée ABSENTE est expliquée comme les autres', () {
    test('masse grasse et masse musculaire : ni calcul, ni estimation', () {
      final explication = NutritionExplanations.masseGrasseEtMusculaire;
      expect(explication.cequeCaNeDitPas, isNotNull);
      // Le serveur ne produit RIEN de tel : le jour où il le ferait, cette
      // explication deviendrait un mensonge.
      expect(
        serveur,
        isNot(contains('bodyFat')),
        reason:
            'Le serveur calcule désormais une masse grasse. L’explication '
            '« ${explication.titre} » affirme le contraire : réécris-la.',
      );
      expect(
        serveur,
        isNot(contains('muscleMass')),
        reason:
            'Le serveur calcule désormais une masse musculaire. '
            'L’explication « ${explication.titre} » affirme le contraire.',
      );
    });
  });
}
