import 'dart:io';

import 'package:health/health.dart';

import '../../../core/logging/app_logger.dart';
import '../../progress/domain/entities/progress.dart';
import '../domain/health_data_source.dart';

/// Health Connect (Android) et Apple Santé (iOS), par le greffon `health`.
///
/// Les seules lectures demandées sont celles-ci : jamais une écriture.
/// Rien n'est testé ici (le greffon ne tourne que sur un vrai téléphone) :
/// ce fichier se contente de TRADUIRE, la logique vit dans les cas d'usage.
class HealthPluginDataSource implements HealthDataSource {
  HealthPluginDataSource([Health? health]) : _health = health ?? Health();

  final Health _health;
  Future<void>? _configured;

  static const _log = AppLogger('HealthPluginDataSource');

  /// LECTURE, dit explicitement : le défaut du greffon l'est aussi, mais
  /// une version qui en changerait ne doit pas faire demander l'écriture.
  static const _readOnly = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
  ];

  Future<void> _ready() => _configured ??= _health.configure();

  @override
  Future<HealthAvailability> availability() async {
    if (!Platform.isAndroid) {
      return Platform.isIOS
          ? HealthAvailability.available
          : HealthAvailability.unsupported;
    }
    await _ready();
    return switch (await _health.getHealthConnectSdkStatus()) {
      HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        HealthAvailability.needsInstall,
      _ => HealthAvailability.unsupported,
    };
  }

  @override
  Future<bool> requestReadAccess() async {
    await _ready();
    final shown = await _health.requestAuthorization(
      _types,
      permissions: _readOnly,
    );
    // Android rend `true` dès qu'UNE lecture est accordée : on vérifie les
    // trois. iOS ne dit rien (null) : la demande montrée vaut accord.
    return shown && await hasReadAccess();
  }

  @override
  Future<bool> hasReadAccess() async {
    await _ready();
    try {
      return await _health.hasPermissions(_types, permissions: _readOnly) ??
          true;
    } on UnsupportedError catch (error) {
      // Health Connect désinstallé depuis la connexion : le greffon lève au
      // lieu de répondre. Plus rien n'est lisible, c'est un « non ».
      _log.warning('Health Connect absent', error: error);
      return false;
    }
  }

  @override
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    await _ready();
    return _health.getTotalStepsInInterval(start, end);
  }

  @override
  Future<List<HealthWeighing>> weighingsBetween(
    DateTime since,
    DateTime until,
  ) async {
    await _ready();
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WEIGHT, HealthDataType.BODY_FAT_PERCENTAGE],
      startTime: since,
      endTime: until,
    );
    return [
      for (final point in points)
        if (_weighing(point) case final weighing?) weighing,
    ];
  }

  HealthWeighing? _weighing(HealthDataPoint point) {
    final value = point.value;
    if (value is! NumericHealthValue) {
      _log.warning('valeur non numérique ignorée (${point.type.name})');
      return null;
    }
    final raw = value.numericValue.toDouble();
    final kind = point.type == HealthDataType.WEIGHT
        ? BodyMetricKind.weightKg
        : BodyMetricKind.bodyFatPercent;
    return HealthWeighing(
      kind: kind,
      // Apple Santé rend la masse grasse en FRACTION (0,25 pour 25 %),
      // Health Connect en pourcentage.
      value:
          kind == BodyMetricKind.bodyFatPercent &&
              point.sourcePlatform == HealthPlatformType.appleHealth
          ? raw * 100
          : raw,
      measuredAt: point.dateFrom.toUtc(),
      // Android : `sourceId` est vide, le paquet est dans `sourceName`.
      sourceApp: point.sourceId.isNotEmpty ? point.sourceId : point.sourceName,
    );
  }
}
