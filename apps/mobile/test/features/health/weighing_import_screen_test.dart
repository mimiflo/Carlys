import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/health/data/health_prefs_store.dart';
import 'package:carlys_mobile/features/health/domain/health_data_source.dart';
import 'package:carlys_mobile/features/health/domain/usecases/import_health_weighings.dart';
import 'package:carlys_mobile/features/health/presentation/providers/health_providers.dart';
import 'package:carlys_mobile/features/health/presentation/widgets/health_import_trigger.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_metric_row.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_weight_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_health_data_source.dart';
import '../../support/fake_progress_repository.dart';

/// PROGRÈS IMPORTE LES PESÉES DE LA BALANCE à son ouverture — et les dit
/// importées, dans la ligne comme dans la dernière mesure.
void main() {
  late FakeHealthDataSource source;
  late FakeProgressRepository metrics;
  final hier = DateTime.now().toUtc().subtract(const Duration(days: 1));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = FakeHealthDataSource(
      weighings: [
        HealthWeighing(
          kind: BodyMetricKind.weightKg,
          value: 78.4,
          measuredAt: hier,
          sourceApp: 'com.withings.wiscale2',
        ),
      ],
    );
    metrics = FakeProgressRepository();
  });

  Future<void> monte(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthDataSourceProvider.overrideWithValue(source),
          healthAccountIdProvider.overrideWithValue('user-1'),
          progressRepositoryProvider.overrideWithValue(metrics),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: HealthImportTrigger(
              child: SingleChildScrollView(child: BodyWeightSection()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('connecté : la pesée arrive à l’ouverture, marquée importée', (
    tester,
  ) async {
    await const HealthPrefsStore().setConnected('user-1', connected: true);
    await monte(tester);

    expect(source.weighingWindows, hasLength(1));
    expect(find.textContaining('importée de la balance'), findsOneWidget);
    expect(find.textContaining(formatDecimal(78.4)), findsWidgets);
  });

  testWidgets('non connecté : rien n’est lu ni importé', (tester) async {
    await monte(tester);

    expect(source.weighingWindows, isEmpty);
    expect(metrics.addedIds, isEmpty);
  });

  testWidgets('la ligne d’une pesée importée le dit, une saisie non', (
    tester,
  ) async {
    final importee = BodyMetricEntry(
      id: weighingMetricId('user-1', source.weighings.single),
      kind: BodyMetricKind.weightKg,
      value: 78.4,
      measuredAt: hier,
    );
    final saisie = BodyMetricEntry(
      id: '0f8fad5b-d9cb-469f-a165-70867728950e',
      kind: BodyMetricKind.weightKg,
      value: 79,
      measuredAt: hier.subtract(const Duration(days: 3)),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Column(
              children: [
                BodyMetricRow(entry: importee, isLatest: true),
                BodyMetricRow(entry: saisie, isLatest: false),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('IMPORTÉE'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('importée de la balance')),
      findsOneWidget,
    );
  });
}
