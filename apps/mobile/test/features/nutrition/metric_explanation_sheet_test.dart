import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/metric_explanation.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/macros_card.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/metabolism_hero.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/metabolism_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un métabolisme complet, aux chiffres distinctifs : chaque valeur doit
/// pouvoir être cherchée à l'écran sans en croiser une autre.
const _resultat = MetabolismResult(
  bmi: 24.7,
  bmiCategory: BmiCategory.normal,
  bmrKcal: 1782,
  tdeeKcal: 2759,
  targetKcal: 2345,
  proteinG: 128,
  fatG: 65,
  carbsG: 291,
  waterMl: 2800,
);

Widget _ecran(Widget enfant) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: enfant,
      ),
    ),
  ),
);

/// Les titres des trois blocs passent par `AppSectionLabel`, qui MAJUSCULE.
/// Le test applique la même transformation plutôt que de recopier le
/// résultat : une casse recopiée à la main dérive au premier accent.
Finder _bloc(String titre) => find.text(titre.toUpperCase());

/// Une phrase que SEULE cette explication contient — assez longue pour ne pas
/// se confondre avec une autre, assez courte pour survivre à une relecture du
/// texte.
String _empreinte(MetricExplanation explication) {
  final mots = explication.cequeCest.split(' ');
  return mots.take(6).join(' ');
}

void main() {
  group('l’explication s’ouvre depuis la donnée elle-même', () {
    testWidgets('la tuile IMC ouvre l’IMC, et rien d’autre', (tester) async {
      await tester.pumpWidget(
        _ecran(const MetabolismView(metabolism: _resultat)),
      );

      expect(_bloc('Ce que c’est'), findsNothing);

      await tester.tap(find.widgetWithText(AppStatTile, 'IMC'));
      await tester.pumpAndSettle();

      expect(_bloc('Ce que c’est'), findsOneWidget);
      expect(_bloc('D’où ça sort'), findsOneWidget);
      expect(find.text(MetricExplanations.imc.titre), findsWidgets);
      expect(
        find.textContaining(_empreinte(MetricExplanations.imc)),
        findsOneWidget,
      );
      // La limite est le bloc le plus utile : un IMC pris au pied de la
      // lettre par un pratiquant de force.
      expect(_bloc('Ce que ça ne dit pas'), findsOneWidget);
    });

    testWidgets('« J’ai compris » referme la feuille', (tester) async {
      await tester.pumpWidget(
        _ecran(const MetabolismView(metabolism: _resultat)),
      );

      await tester.tap(find.widgetWithText(AppStatTile, 'IMC'));
      await tester.pumpAndSettle();
      expect(_bloc('Ce que c’est'), findsOneWidget);

      await tester.tap(find.text('J’ai compris'));
      await tester.pumpAndSettle();
      expect(_bloc('Ce que c’est'), findsNothing);
    });

    testWidgets('chaque ligne de macro ouvre SA macro', (tester) async {
      final attendus = {
        'Protéines': MetricExplanations.proteines,
        'Glucides': MetricExplanations.glucides,
        'Lipides': MetricExplanations.lipides,
      };

      for (final entree in attendus.entries) {
        await tester.pumpWidget(
          _ecran(const MetabolismView(metabolism: _resultat)),
        );
        await tester.tap(find.widgetWithText(MacroRow, entree.key));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(_empreinte(entree.value)),
          findsOneWidget,
          reason: '« ${entree.key} » n’a pas ouvert « ${entree.value.titre} ».',
        );
        // Aucune AUTRE macro ne s'est ouverte au passage.
        for (final autre in attendus.values) {
          if (identical(autre, entree.value)) continue;
          expect(find.textContaining(_empreinte(autre)), findsNothing);
        }

        await tester.tap(find.text('J’ai compris'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('l’objectif calorique s’explique depuis l’en-tête', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ecran(const MetabolismView(metabolism: _resultat)),
      );

      await tester.tap(find.textContaining('OBJECTIF 2'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(_empreinte(MetricExplanations.caloriesCibles)),
        findsOneWidget,
      );
    });

    testWidgets('la donnée ABSENTE a sa porte, elle aussi', (tester) async {
      await tester.pumpWidget(
        _ecran(const MetabolismView(metabolism: _resultat)),
      );

      await tester.tap(find.text('Et ma masse grasse ?'));
      await tester.pumpAndSettle();

      final explication = MetricExplanations.masseGrasseEtMusculaire;
      expect(find.textContaining(_empreinte(explication)), findsOneWidget);
      expect(find.textContaining('Carlys ne les affiche pas'), findsOneWidget);
    });

    testWidgets('le hero explique la dépense et le métabolisme de base', (
      tester,
    ) async {
      // L'hélice ADN tourne en BOUCLE : sans réduction d'animations,
      // `pumpAndSettle` n'atteint jamais le repos et expire.
      TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures.allOn;
      addTearDown(
        TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .clearAccessibilityFeaturesTestValue,
      );

      Widget hero() => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: MetabolismHero(metabolism: _resultat, onCompleteProfile: () {}),
        ),
      );

      await tester.pumpWidget(hero());
      await tester.tap(find.text('2 759'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(_empreinte(MetricExplanations.depenseEnergetique)),
        findsOneWidget,
      );
      await tester.tap(find.text('J’ai compris'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('MB 1 782'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(_empreinte(MetricExplanations.metabolismeDeBase)),
        findsOneWidget,
      );
    });
  });

  group('accessibilité des portes d’explication', () {
    testWidgets('une donnée explicable s’annonce comme un bouton', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _ecran(const MetabolismView(metabolism: _resultat)),
      );

      // La valeur d'abord, l'existence de l'explication ensuite : le lecteur
      // d'écran donne la donnée avant d'annoncer ce qu'on peut en faire.
      expect(
        tester.getSemantics(find.widgetWithText(AppStatTile, 'IMC')).label,
        'IMC : 24,7. Explication',
      );
      expect(
        tester.getSemantics(find.widgetWithText(MacroRow, 'Protéines')).label,
        'Protéines : 128 g par jour. Explication',
      );

      handle.dispose();
    });

    testWidgets('chaque porte dépasse la cible tactile minimale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ecran(const MetabolismView(metabolism: _resultat)),
      );

      for (final ligne in const ['Protéines', 'Glucides', 'Lipides']) {
        expect(
          tester.getSize(find.widgetWithText(MacroRow, ligne)).height,
          greaterThanOrEqualTo(AppSpacing.touchTarget),
          reason: 'La ligne « $ligne » est trop courte pour un doigt.',
        );
      }
      for (final tuile in const ['IMC', 'EAU']) {
        expect(
          tester.getSize(find.widgetWithText(AppStatTile, tuile)).height,
          greaterThanOrEqualTo(AppSpacing.touchTarget),
          reason: 'La tuile « $tuile » est trop courte pour un doigt.',
        );
      }
    });
  });
}
