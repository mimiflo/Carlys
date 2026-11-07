import 'package:carlys_mobile/features/health/domain/health_data_source.dart';

/// Health Connect / Apple Santé de test : tout en mémoire, aucun greffon.
class FakeHealthDataSource implements HealthDataSource {
  FakeHealthDataSource({
    this.available = HealthAvailability.available,
    this.grants = true,
    this.steps = 0,
    List<HealthWeighing>? weighings,
  }) : weighings = [...?weighings];

  HealthAvailability available;

  /// Ce que la personne répond à la demande (et garde ensuite).
  bool grants;
  int? steps;
  final List<HealthWeighing> weighings;

  int accessRequests = 0;
  int installRequests = 0;
  int stepReads = 0;

  /// Les fenêtres demandées, pour vérifier « depuis le dernier import ».
  final List<(DateTime, DateTime)> weighingWindows = [];

  @override
  Future<HealthAvailability> availability() async => available;

  @override
  Future<bool> requestReadAccess() async {
    accessRequests++;
    return grants;
  }

  @override
  Future<bool> hasReadAccess() async => grants;

  @override
  Future<void> installHealthConnect() async => installRequests++;

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    stepReads++;
    return steps;
  }

  @override
  Future<List<HealthWeighing>> weighingsBetween(
    DateTime since,
    DateTime until,
  ) async {
    weighingWindows.add((since, until));
    return [
      for (final weighing in weighings)
        if (!weighing.measuredAt.isBefore(since) &&
            !weighing.measuredAt.isAfter(until))
          weighing,
    ];
  }
}
