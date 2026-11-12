import 'package:carlys_mobile/features/health/data/health_prefs_store.dart';
import 'package:carlys_mobile/features/health/domain/health_data_source.dart';
import 'package:carlys_mobile/features/health/presentation/providers/health_providers.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/providers/progress_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_health_data_source.dart';
import '../../support/fake_progress_repository.dart';

/// L'IMPORT DÉCLENCHÉ PAR PROGRÈS : un seul à la fois, et la courbe ne se
/// relit que si un poids NOUVEAU est arrivé.
void main() {
  late FakeHealthDataSource source;
  late FakeProgressRepository metrics;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await const HealthPrefsStore().setConnected('user-1', connected: true);
    source = FakeHealthDataSource(
      weighings: [
        HealthWeighing(
          kind: BodyMetricKind.weightKg,
          value: 80.2,
          measuredAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
          sourceApp: 'com.withings.wiscale2',
        ),
      ],
    );
    metrics = FakeProgressRepository();
    container = ProviderContainer(
      overrides: [
        healthDataSourceProvider.overrideWithValue(source),
        healthAccountIdProvider.overrideWithValue('user-1'),
        progressRepositoryProvider.overrideWithValue(metrics),
      ],
    );
    addTearDown(container.dispose);
    // La courbe est affichée : c'est elle que l'import rafraîchit.
    container.listen(bodyWeightMetricsProvider, (_, _) {});
    await container.read(bodyWeightMetricsProvider.future);
  });

  test('deux déclenchements croisés : UN seul import', () async {
    final import = container.read(healthWeighingImportProvider);
    await Future.wait([import.run(), import.run()]);

    expect(source.weighingWindows, hasLength(1));
    expect(metrics.addedIds, hasLength(1));
  });

  test('un poids nouveau relit la courbe ; un rejeu, non', () async {
    final import = container.read(healthWeighingImportProvider);
    final before = metrics.bodyMetricReads;
    await import.run();
    await container.read(bodyWeightMetricsProvider.future);
    expect(metrics.bodyMetricReads, before + 1);

    // Réinstallation simulée : le curseur oublié, la même pesée relue — la
    // courbe l'a déjà, elle ne se relit pas.
    await const HealthPrefsStore().markImported('user-1', DateTime.utc(2000));
    await import.run();
    await container.read(bodyWeightMetricsProvider.future);
    expect(metrics.addedIds, hasLength(2));
    expect(metrics.bodyMetricReads, before + 1);
  });
}
