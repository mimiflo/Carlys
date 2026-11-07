import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/dashboard/presentation/providers/today_metrics.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_grid.dart';
import 'package:carlys_mobile/features/health/data/health_prefs_store.dart';
import 'package:carlys_mobile/features/health/presentation/providers/health_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_lifecycle.dart';
import '../../support/fake_health_data_source.dart';

/// LES PAS SUR L'ACCUEIL : une rangée sous la grille du jour, et seulement
/// quand la santé connectée est active. Lus à l'ouverture, au retour au
/// premier plan et toutes les cinq minutes — jamais envoyés nulle part.
void main() {
  late FakeHealthDataSource source;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = FakeHealthDataSource(steps: 6214);
  });

  TodayMetric mesure(TodayMetricKind kind) => TodayMetric(
    kind: kind,
    label: kind.name,
    value: '1',
    target: '/ 2',
    note: 'reste 1',
    ratio: 0.5,
  );

  /// La grille de l'accueil, branchée sur le VRAI provider des pas.
  Future<void> monte(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthDataSourceProvider.overrideWithValue(source),
          healthAccountIdProvider.overrideWithValue('user-1'),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TodayGrid(
                metrics: [
                  for (final kind in TodayMetricKind.values.take(4))
                    mesure(kind),
                ],
                steps: ref.watch(todayStepsMetricProvider),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('non connecté : aucune cellule de pas, la grille d’avant', (
    tester,
  ) async {
    await monte(tester);

    expect(find.text('PAS'), findsNothing);
    expect(source.stepReads, 0);
  });

  testWidgets('connecté : les pas du jour face à l’objectif', (tester) async {
    await const HealthPrefsStore().setConnected('user-1', connected: true);
    await monte(tester);

    expect(find.text('PAS'), findsOneWidget);
    expect(find.text(formatThousands(6214)), findsOneWidget);
    expect(find.text('/ ${formatThousands(8000)} pas'), findsOneWidget);
    expect(
      find.text('reste ${formatThousands(8000 - 6214)} pas'),
      findsOneWidget,
    );
  });

  testWidgets('l’objectif réglé remplace le défaut', (tester) async {
    await const HealthPrefsStore().setConnected('user-1', connected: true);
    await const HealthPrefsStore().setStepsGoal('user-1', 5000);
    source.steps = 7000;
    await monte(tester);

    expect(find.text('objectif atteint'), findsOneWidget);
  });

  testWidgets('relus au retour au premier plan, et toutes les cinq minutes', (
    tester,
  ) async {
    await const HealthPrefsStore().setConnected('user-1', connected: true);
    await monte(tester);
    expect(source.stepReads, 1);

    source.steps = 7100;
    await leaveAndComeBack(tester);
    await tester.pumpAndSettle();
    expect(source.stepReads, 2);
    expect(find.text(formatThousands(7100)), findsOneWidget);

    await tester.pump(stepsRefreshInterval);
    await tester.pumpAndSettle();
    expect(source.stepReads, 3);
  });

  testWidgets('lecture impossible : on le dit, sans chiffre inventé', (
    tester,
  ) async {
    await const HealthPrefsStore().setConnected('user-1', connected: true);
    source.steps = null;
    await monte(tester);

    expect(find.text('PAS'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('lecture impossible'), findsOneWidget);
  });
}
