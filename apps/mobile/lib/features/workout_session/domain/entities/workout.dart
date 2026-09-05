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

  static LocalSyncState fromDb(String value) =>
      LocalSyncState.values.firstWhere(
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
    this.templateId,
    this.templateName,
  });

  final String id;
  final String? name;
  final WorkoutStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  /// Modèle de séance lancé, s'il y en a un.
  final String? templateId;

  /// Nom du modèle au moment du lancement — provenance immuable, à distinguer
  /// de [name] qui reste le titre modifiable de CETTE séance.
  final String? templateName;

  final LocalSyncState syncState;

  /// `true` quand la séance a été lancée depuis un modèle.
  bool get isFromTemplate => templateName != null;
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
    this.plannedReps,
    this.plannedWeightKg,
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

  /// Cible AFFICHÉE au moment de la validation (null hors modèle). Permet de
  /// relire « prévu 8 × 60 kg, fait 7 × 60 kg » des mois plus tard, sans
  /// dépendre de la survie du modèle.
  final int? plannedReps;
  final double? plannedWeightKg;

  final DateTime completedAt;
  final LocalSyncState syncState;

  /// `true` quand la série portait une cible et s'en est écartée.
  /// Une déviation est **normale**, jamais une erreur.
  bool get deviatesFromPlan =>
      (plannedReps != null && reps != null && plannedReps != reps) ||
      (plannedWeightKg != null &&
          weightKg != null &&
          plannedWeightKg != weightKg);
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
    this.plannedReps,
    this.plannedWeightKg,
    this.planItemId,
  });

  final String sessionId;
  final String? exerciseId;
  final String exerciseName;
  final SetKind kind;
  final int? reps;
  final double? weightKg;
  final int? restSeconds;
  final int? rpe;

  /// Cible affichée à l'instant de la validation. Renseignée par le cas
  /// d'usage d'appariement au plan, jamais saisie à la main par un écran.
  final int? plannedReps;
  final double? plannedWeightKg;

  /// Prévision du plan que cette série honore, renseignée par le même cas
  /// d'usage. Elle voyage AVEC la série : l'appariement se retrouve donc sur
  /// un autre appareil sans opération de synchronisation supplémentaire.
  final String? planItemId;

  AddSetInput copyWith({
    int? plannedReps,
    double? plannedWeightKg,
    String? planItemId,
  }) {
    return AddSetInput(
      sessionId: sessionId,
      exerciseName: exerciseName,
      exerciseId: exerciseId,
      kind: kind,
      reps: reps,
      weightKg: weightKg,
      restSeconds: restSeconds,
      rpe: rpe,
      plannedReps: plannedReps ?? this.plannedReps,
      plannedWeightKg: plannedWeightKg ?? this.plannedWeightKg,
      planItemId: planItemId ?? this.planItemId,
    );
  }
}
