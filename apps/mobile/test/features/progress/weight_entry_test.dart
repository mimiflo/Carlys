import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/add_weight_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_progress_repository.dart';

/// CE QUE CE FICHIER PROTÈGE : la saisie du poids ne se faisait qu'au pas de
/// 0,5 kg, par deux flèches, et toute mesure était datée de l'instant. On ne
/// pouvait donc ni taper 72,4, ni rattraper la pesée de la veille, ni
/// corriger une valeur fausse — alors que c'est le DERNIER poids, choisi par
/// sa date, qui décide des besoins caloriques affichés ailleurs.
void main() {
  /// Ce que la feuille a rapporté, lu APRÈS sa fermeture.
  ///
  /// Un simple `return` ne marcherait pas : la valeur n'existe qu'une fois la
  /// feuille refermée, donc bien après que le helper a rendu la main.
  final rapporte = <BodyWeightInput>[];

  /// Monte la feuille, comme un écran le ferait.
  Future<void> ouvrir(
    WidgetTester tester, {
    double? initialKg,
    DateTime? initialDate,
    bool correction = false,
  }) async {
    rapporte.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final saisie = await showAddWeightSheet(
                  context,
                  initialKg: initialKg,
                  initialDate: initialDate,
                  correction: correction,
                );
                if (saisie != null) rapporte.add(saisie);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('accepte une valeur tapée au dixième, pas seulement les 0,5', (
    tester,
  ) async {
    await ouvrir(tester, initialKg: 70);

    await tester.enterText(find.byType(TextField), '72.4');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // 72,4 n'est atteignable par AUCUNE succession de pas de 0,5 depuis 70 :
    // si cette valeur ressort, c'est bien la saisie libre qui a parlé.
    expect(rapporte.single.valueKg, 72.4);
  });

  testWidgets('la virgule française est acceptée', (tester) async {
    await ouvrir(tester, initialKg: 70);

    // Sur un clavier numérique français, la séparatrice décimale EST la
    // virgule : la refuser rendrait la saisie impossible sans explication.
    await tester.enterText(find.byType(TextField), '68,7');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(rapporte.single.valueKg, 68.7);
  });

  testWidgets('une valeur hors bornes désactive l’enregistrement', (
    tester,
  ) async {
    await ouvrir(tester, initialKg: 70);

    await tester.enterText(find.byType(TextField), '900');
    await tester.pump();

    expect(find.text('Entre 30.0 et 400.0 kg.'), findsOneWidget);
  });

  testWidgets('les flèches écrivent dans le champ, qui reste la vérité', (
    tester,
  ) async {
    await ouvrir(tester, initialKg: 70);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.widgetWithText(TextField, '70.5'), findsOneWidget);
  });

  testWidgets('la date est proposée, et vaut aujourd’hui par défaut', (
    tester,
  ) async {
    await ouvrir(tester, initialKg: 70);

    expect(find.text('Date de la pesée'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsOneWidget);
  });

  testWidgets(
    'en correction, le titre, le bouton et l’avertissement changent',
    (tester) async {
      await ouvrir(
        tester,
        initialKg: 88.4,
        initialDate: DateTime(2026, 8, 6),
        correction: true,
      );

      expect(find.text('Corriger cette pesée'), findsOneWidget);
      expect(find.text('Corriger'), findsOneWidget);
      expect(find.text('Enregistrer'), findsNothing);
      // La conséquence est DITE : corriger déplace les besoins caloriques.
      expect(find.textContaining('besoins'), findsOneWidget);
      // La date corrigée est celle de la mesure, pas celle du jour.
      expect(find.text('06/08/2026'), findsOneWidget);
      expect(find.widgetWithText(TextField, '88.4'), findsOneWidget);
    },
  );

  test(
    'le faux dépôt corrige en place, et refuse une mesure inconnue',
    () async {
      final depot = FakeProgressRepository(
        bodyMetrics: [
          BodyMetricEntry(
            id: 'm1',
            kind: BodyMetricKind.weightKg,
            value: 90,
            measuredAt: DateTime.utc(2026, 8, 7),
          ),
        ],
      );

      final corrigee = await depot.updateBodyMetric(id: 'm1', value: 88.4);
      expect(corrigee.value, 88.4);
      // La date n'a pas bougé : on ne corrige que ce qu'on envoie.
      expect(corrigee.measuredAt, DateTime.utc(2026, 8, 7));

      await expectLater(
        depot.updateBodyMetric(id: 'inconnue', value: 70),
        throwsStateError,
      );
    },
  );
}
