/// Entités du domaine séance (immuables, écrites à la main).
library;

enum WorkoutStatus {
  inProgress('IN_PROGRESS', 'En cours'),
  completed('COMPLETED', 'Terminée'),
  abandoned('ABANDONED', 'Abandonnée');

  const WorkoutStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static WorkoutStatus fromApi(String value) => WorkoutStatus.values.firstWhere(
        (status) => status.apiValue == value,
        orElse: () => WorkoutStatus.inProgress,
      );
}

enum SetKind {
  warmup('WARMUP', 'Échauffement'),
  normal('NORMAL', 'Série'),
  drop('DROP', 'Dégressive');

  const SetKind(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SetKind fromApi(String value) => SetKind.values.firstWhere(
        (kind) => kind.apiValue == value,
        orElse: () => SetKind.normal,
      );
}

/// État de synchronisation local d'une entité.
enum LocalSyncState {
  pending('pending', 'En attente'),
  synced('synced', 'Synchronisé'),
  failed('failed', 'Échec');

  const LocalSyncState(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static LocalSyncState fromDb(String value) => LocalSyncState.values.firstWhere(
        (state) => state.dbValue == value,
        orElse: () => LocalSyncState.pending,
      );
}

class WorkoutInfo {
  const WorkoutInfo({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.syncState,
    this.name,
    this.endedAt,
    this.durationSeconds,
  });

  final String id;
  final String? name;
  final WorkoutStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final LocalSyncState syncState;
}

class WorkoutSetEntry {
  const WorkoutSetEntry({
    required this.id,
    required this.exerciseName,
    required this.position,
    required this.kind,
    required this.completedAt,
    required this.syncState,
    this.exerciseId,
    this.reps,
    this.weightKg,
    this.restSeconds,
    this.rpe,
  });

  final String id;
  final String? exerciseId;
  final String exerciseName;
  final int position;
  final SetKind kind;
  final int? reps;
  final double? weightKg;
  final int? restSeconds;
  final int? rpe;
  final DateTime completedAt;
  final LocalSyncState syncState;
}

/// Séance avec ses séries (active ou historique).
class WorkoutWithSets {
  const WorkoutWithSets({required this.session, required this.sets});

  final WorkoutInfo session;
  final List<WorkoutSetEntry> sets;

  int get setsCount => sets.length;

  double get totalVolumeKg => sets.fold(0, (total, set) {
        if (set.reps == null || set.weightKg == null) {
          return total;
        }
        return total + set.reps! * set.weightKg!;
      });
}

class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.session,
    required this.setsCount,
    required this.totalVolumeKg,
  });

  final WorkoutInfo session;
  final int setsCount;
  final double totalVolumeKg;
}

/// Saisie d'une nouvelle série.
class AddSetInput {
  const AddSetInput({
    required this.sessionId,
    required this.exerciseName,
    this.exerciseId,
    this.kind = SetKind.normal,
    this.reps,
    this.weightKg,
    this.restSeconds,
    this.rpe,
  });

  final String sessionId;
  final String? exerciseId;
  final String exerciseName;
  final SetKind kind;
  final int? reps;
  final double? weightKg;
  final int? restSeconds;
  final int? rpe;
}
