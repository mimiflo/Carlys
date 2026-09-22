import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/dashboard/presentation/controllers/today_metrics.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE LA GRILLE DU JOUR PROPOSE, ET CE QU'ELLE NE PROPOSE PAS.
///
/// La tuile des calories montrait le total du jour sans offrir de le
/// nourrir : noter un repas demandait un changement d'onglet puis un
/// défilement, alors que l'envie de le noter naît précisément en lisant ce
/// chiffre-là. L'hydratation, elle, avait son geste depuis toujours.
///
/// Le revers compte autant : les deux autres cellules viennent des séances,
/// n'ont aucun geste, et ne doivent surtout pas faire croire le contraire.
/// Une cellule qui ressemble à un bouton et ne répond pas est pire qu'une
/// cellule inerte.
void main() {
  TodayMetric mesure(TodayMetricKind kind) => TodayMetric(
    kind: kind,
    label: 'Mesure',
    value: '1 240',
    target: '/ 2 300 kcal',
    note: 'il reste 1 060',
    ratio: 0.54,
  );

  /// Les quatre mesures, dans l'ordre où la grille les attend.
  final quatre = [
    mesure(TodayMetricKind.calories),
    mesure(TodayMetricKind.hydratation),
    mesure(TodayMetricKind.proteines),
    mesure(TodayMetricKind.volume),
  ];

  Future<List<TodayMetricKind>> tapotees(
    WidgetTester tester, {
    required bool avecRepas,
  }) async {
    final touchees = <TodayMetricKind>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: TodayGrid(
            metrics: quatre,
            onOpenHydration: () => touchees.add(TodayMetricKind.hydratation),
            onAddMeal: avecRepas
                ? () => touchees.add(TodayMetricKind.calories)
                : null,
          ),
        ),
      ),
    );

    for (final cellule in tester.widgetList<TodayCell>(
      find.byType(TodayCell),
    )) {
      await tester.tap(find.byWidget(cellule));
      await tester.pump();
    }
    return touchees;
  }

  testWidgets('les calories et l’eau répondent, les deux autres non', (
    tester,
  ) async {
    final touchees = await tapotees(tester, avecRepas: true);

    expect(touchees, hasLength(2));
    expect(touchees, contains(TodayMetricKind.calories));
    expect(touchees, contains(TodayMetricKind.hydratation));
  });

  testWidgets('sans geste de repas, seule l’eau répond', (tester) async {
    // Le rappel passe `null` : la tuile redevient muette, et rien ne doit
    // la faire paraître actionnable pour autant.
    final touchees = await tapotees(tester, avecRepas: false);

    expect(touchees, [TodayMetricKind.hydratation]);
  });

  testWidgets('une cellule actionnable se DIT bouton, les autres non', (
    tester,
  ) async {
    // La sémantique, et pas seulement le tap : sans `button: true`, un
    // lecteur d'écran annonce la tuile comme un texte, et le geste reste
    // invisible à qui ne voit pas la grille.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: TodayGrid(
            metrics: quatre,
            onOpenHydration: () {},
            onAddMeal: () {},
          ),
        ),
      ),
    );

    var boutons = 0;
    for (final cellule in tester.widgetList<TodayCell>(
      find.byType(TodayCell),
    )) {
      final noeud = tester.getSemantics(find.byWidget(cellule));
      if (noeud.flagsCollection.isButton) {
        boutons++;
      }
    }
    expect(boutons, 2, reason: 'les calories et l’eau, elles seules');
    handle.dispose();
  });
}
