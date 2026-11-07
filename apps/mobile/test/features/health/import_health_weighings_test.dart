import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/health/data/health_prefs_store.dart';
import 'package:carlys_mobile/features/health/domain/health_data_source.dart';
import 'package:carlys_mobile/features/health/domain/usecases/import_health_weighings.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_health_data_source.dart';
import '../../support/fake_progress_repository.dart';

const _user = 'user-1';
final _now = DateTime.utc(2026, 11, 6, 9);

HealthWeighing _pesee(
  double kg, {
  int joursAvant = 1,
  BodyMetricKind kind = BodyMetricKind.weightKg,
  String source = 'com.withings.wiscale2',
}) => HealthWeighing(
  kind: kind,
  value: kg,
  measuredAt: _now.subtract(Duration(days: joursAvant, hours: 2)),
  sourceApp: source,
);

void main() {
  late FakeHealthDataSource source;
  late FakeProgressRepository metrics;
  late HealthPrefsStore ledger;
  late ImportHealthWeighings import;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = FakeHealthDataSource();
    metrics = FakeProgressRepository();
    ledger = const HealthPrefsStore();
    import = ImportHealthWeighings(
      source: source,
      metrics: metrics,
      ledger: ledger,
    );
  });

  Future<List<BodyMetricEntry>> poids() => metrics.bodyMetrics();

  group('weighingMetricId', () {
    test('un UUID v5, stable, que la version suffit à reconnaître', () {
      final id = weighingMetricId(_user, _pesee(80));
      expect(id, weighingMetricId(_user, _pesee(80)));
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-')));
      final entry = BodyMetricEntry(
        id: id,
        kind: BodyMetricKind.weightKg,
        value: 80,
        measuredAt: _now,
      );
      expect(entry.imported, isTrue);
      // Une saisie à la main (UUID v4) n'est pas « importée ».
      final saisie = BodyMetricEntry(
        id: '0f8fad5b-d9cb-469f-a165-70867728950e',
        kind: BodyMetricKind.weightKg,
        value: 80,
        measuredAt: _now,
      );
      expect(saisie.imported, isFalse);
    });

    test('la même pesée relue ailleurs (autre enregistrement, à la '
        'milliseconde près) garde son identifiant', () {
      final a = _pesee(80);
      final b = HealthWeighing(
        kind: a.kind,
        value: a.value,
        measuredAt: a.measuredAt.add(const Duration(milliseconds: 400)),
        sourceApp: 'com.sec.android.app.shealth',
      );
      expect(weighingMetricId(_user, b), weighingMetricId(_user, a));
    });

    test('change avec le compte, le type et la seconde', () {
      final id = weighingMetricId(_user, _pesee(80));
      expect(weighingMetricId('user-2', _pesee(80)), isNot(id));
      expect(
        weighingMetricId(
          _user,
          _pesee(20, kind: BodyMetricKind.bodyFatPercent),
        ),
        isNot(id),
      );
      expect(weighingMetricId(_user, _pesee(80, joursAvant: 2)), isNot(id));
    });
  });

  group('bornes', () {
    test('hors de la plage d’une balance : écartée', () {
      expect(plausibleWeighing(_pesee(0)), isNull);
      expect(plausibleWeighing(_pesee(19.9)), isNull);
      expect(plausibleWeighing(_pesee(351)), isNull);
      expect(plausibleWeighing(_pesee(double.nan)), isNull);
      const fat = BodyMetricKind.bodyFatPercent;
      // Une masse grasse lue en fraction (0,25) n'est pas 0,25 %.
      expect(plausibleWeighing(_pesee(0.25, kind: fat)), isNull);
      expect(plausibleWeighing(_pesee(80, kind: fat)), isNull);
      expect(plausibleWeighing(_pesee(24.5, kind: fat)), 24.5);
    });

    test('arrondie à la précision de l’API', () {
      expect(plausibleWeighing(_pesee(72.4561)), 72.46);
    });
  });

  test('premier import : 30 jours, les pesées plausibles, rien de Carlys ni '
      'du futur', () async {
    source.weighings.addAll([
      _pesee(80.2),
      _pesee(22.4, kind: BodyMetricKind.bodyFatPercent),
      _pesee(0.4), // balance frôlée
      _pesee(79, source: 'com.carlys.carlys_mobile'),
      _pesee(79, joursAvant: -1), // horloge de la balance en avance
    ]);

    expect(await import(userId: _user, now: _now), 2);

    expect(
      source.weighingWindows.single.$1,
      _now.subtract(const Duration(days: 30)),
    );
    expect((await poids()).map((m) => m.value), [80.2]);
    expect(
      (await metrics.bodyMetrics(
        kind: BodyMetricKind.bodyFatPercent,
      )).single.imported,
      isTrue,
    );
    expect(await ledger.lastImportAt(_user), _now);
  });

  test('ensuite : depuis le dernier import, recouvrement compris, et pas '
      'plus d’une fois par quart d’heure', () async {
    await import(userId: _user, now: _now);

    expect(
      await import(userId: _user, now: _now.add(const Duration(minutes: 10))),
      0,
    );
    expect(source.weighingWindows, hasLength(1));

    final later = _now.add(const Duration(hours: 3));
    await import(userId: _user, now: later);
    expect(
      source.weighingWindows.last.$1,
      _now.subtract(ImportHealthWeighings.overlap),
    );
    expect(await ledger.lastImportAt(_user), later);
  });

  test('idempotent : réimporter (réinstallation, autre téléphone) ne crée '
      'aucun doublon', () async {
    source.weighings.add(_pesee(80.2));
    await import(userId: _user, now: _now);
    // Réinstallation : l'appareil a tout oublié.
    SharedPreferences.setMockInitialValues({});
    await import(userId: _user, now: _now.add(const Duration(hours: 1)));

    expect(metrics.addedIds, hasLength(2));
    expect(metrics.addedIds.toSet(), hasLength(1));
    expect(await poids(), hasLength(1));
  });

  test('une pesée supprimée dans Carlys ne revient pas', () async {
    source.weighings.add(_pesee(80.2));
    await import(userId: _user, now: _now);
    await metrics.deleteBodyMetric((await poids()).single.id);

    SharedPreferences.setMockInitialValues({});
    await import(userId: _user, now: _now.add(const Duration(hours: 1)));

    expect(await poids(), isEmpty);
  });

  test('hors ligne : l’erreur remonte et le curseur ne bouge pas', () async {
    source.weighings.add(_pesee(80.2));
    metrics.addError = const NetworkException('hors ligne');

    await expectLater(
      import(userId: _user, now: _now),
      throwsA(isA<NetworkException>()),
    );
    expect(await ledger.lastImportAt(_user), isNull);
  });

  test(
    'refusée par le serveur : écartée, sans bloquer les suivantes',
    () async {
      source.weighings.add(_pesee(80.2));
      metrics.addError = const ValidationException('refusée', statusCode: 400);

      expect(await import(userId: _user, now: _now), 0);
      expect(await ledger.lastImportAt(_user), _now);
    },
  );

  test('chaque compte a son curseur', () async {
    await import(userId: _user, now: _now);
    expect(await ledger.lastImportAt('user-2'), isNull);
  });
}
