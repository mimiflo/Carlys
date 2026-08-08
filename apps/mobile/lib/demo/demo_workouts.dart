/// Séances du MODE DÉMO — jeu d'exemple en mémoire.
///
/// EXCEPTION DOCUMENTÉE à la règle « pas de données codées en dur » : ce
/// fichier n'est compilé que pour le flavor `demo`, dont la raison d'être est
/// de faire visiter l'app sans serveur ni compte. Le mode `development` et la
/// production passent toujours par Drift et l'API.
///
/// Les dates sont RELATIVES à aujourd'hui : l'historique, le calendrier et les
/// barres de la semaine restent cohérents quelle que soit la date de visite.
library;

import 'dart:async';

import '../features/workout_session/domain/entities/workout.dart';
import '../features/workout_session/domain/repositories/workout_repository.dart';

/// Gabarit d'une séance de démonstration.
class _DemoSession {
  const _DemoSession({
    required this.daysAgo,
    required this.name,
    required this.durationMinutes,
    required this.sets,
  });

  final int daysAgo;
  final String name;
  final int durationMinutes;

  /// (exercice, type, répétitions, charge) — dans l'ordre d'exécution.
  final List<(String, SetKind, int, double)> sets;
}

const List<_DemoSession> _sessions = [
  _DemoSession(
    daysAgo: 1,
    name: 'Push — Force',
    durationMinutes: 54,
    sets: [
      ('Développé couché', SetKind.warmup, 12, 40),
      ('Développé couché', SetKind.normal, 8, 70),
      ('Développé couché', SetKind.normal, 8, 75),
      ('Développé couché', SetKind.normal, 6, 80),
      ('Développé militaire', SetKind.normal, 10, 40),
      ('Développé militaire', SetKind.normal, 10, 42.5),
      ('Dips', SetKind.normal, 12, 0),
      ('Dips', SetKind.normal, 10, 0),
    ],
  ),
  _DemoSession(
    daysAgo: 3,
    name: 'Pull — Hypertrophie',
    durationMinutes: 61,
    sets: [
      ('Rowing barre', SetKind.warmup, 12, 40),
      ('Rowing barre', SetKind.normal, 10, 70),
      ('Rowing barre', SetKind.normal, 10, 72.5),
      ('Traction pronation', SetKind.normal, 9, 0),
      ('Traction pronation', SetKind.normal, 7, 0),
      ('Curl haltères', SetKind.normal, 12, 14),
      ('Curl haltères', SetKind.normal, 11, 14),
    ],
  ),
  _DemoSession(
    daysAgo: 5,
    name: 'Jambes',
    durationMinutes: 48,
    sets: [
      ('Squat arrière', SetKind.warmup, 10, 60),
      ('Squat arrière', SetKind.normal, 8, 100),
      ('Squat arrière', SetKind.normal, 6, 110),
      ('Soulevé de terre', SetKind.normal, 5, 130),
      ('Soulevé de terre', SetKind.normal, 5, 140),
      ('Fentes marchées', SetKind.normal, 12, 20),
    ],
  ),
  _DemoSession(
    daysAgo: 8,
    name: 'Push — Volume',
    durationMinutes: 57,
    sets: [
      ('Développé couché', SetKind.normal, 10, 65),
      ('Développé couché', SetKind.normal, 10, 65),
      ('Développé incliné', SetKind.normal, 10, 50),
      ('Développé incliné', SetKind.normal, 9, 50),
      ('Élévations latérales', SetKind.normal, 15, 10),
    ],
  ),
  _DemoSession(
    daysAgo: 10,
    name: 'Full body',
    durationMinutes: 45,
    sets: [
      ('Squat arrière', SetKind.normal, 8, 95),
      ('Développé couché', SetKind.normal, 8, 70),
      ('Rowing barre', SetKind.normal, 10, 65),
      ('Gainage', SetKind.normal, 3, 0),
    ],
  ),
  _DemoSession(
    daysAgo: 13,
    name: 'Pull — Force',
    durationMinutes: 52,
    sets: [
      ('Soulevé de terre', SetKind.normal, 5, 125),
      ('Soulevé de terre', SetKind.normal, 4, 135),
      ('Traction pronation', SetKind.normal, 8, 0),
      ('Curl haltères', SetKind.normal, 12, 12),
    ],
  ),
];

/// Dépôt de séances du mode démo : historique pré-rempli, séance en cours
/// pleinement fonctionnelle (démarrage, ajout et suppression de séries,
/// clôture) — le tout en mémoire, sans Drift ni réseau.
class DemoWorkoutRepository implements WorkoutRepository {
  DemoWorkoutRepository() {
    _history = _buildHistory();
  }

  late final List<WorkoutHistoryEntry> _history;
  final _activeController = StreamController<WorkoutWithSets?>.broadcast();
  WorkoutWithSets? _active;
  int _nextId = 0;

  static List<WorkoutHistoryEntry> _buildHistory() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entries = <WorkoutHistoryEntry>[];

    for (final (index, session) in _sessions.indexed) {
      final startedAt = today
          .subtract(Duration(days: session.daysAgo))
          .add(const Duration(hours: 18))
          .toUtc();
      final volume = session.sets.fold<double>(
        0,
        (total, set) => total + set.$3 * set.$4,
      );
      entries.add(
        WorkoutHistoryEntry(
          session: WorkoutInfo(
            id: 'demo-session-$index',
            name: session.name,
            status: WorkoutStatus.completed,
            startedAt: startedAt,
            endedAt: startedAt.add(Duration(minutes: session.durationMinutes)),
            durationSeconds: session.durationMinutes * 60,
            syncState: LocalSyncState.synced,
          ),
          setsCount: session.sets.length,
          totalVolumeKg: volume,
        ),
      );
    }
    return entries;
  }

  /// Séries d'une séance passée, reconstruites à la demande pour le détail.
  List<WorkoutSetEntry> _setsOf(int sessionIndex) {
    final session = _sessions[sessionIndex];
    final entry = _history[sessionIndex];
    return [
      for (final (position, set) in session.sets.indexed)
        WorkoutSetEntry(
          id: 'demo-set-$sessionIndex-$position',
          exerciseName: set.$1,
          position: position,
          kind: set.$2,
          reps: set.$3,
          weightKg: set.$4 == 0 ? null : set.$4,
          restSeconds: 90,
          completedAt: entry.session.startedAt.add(
            Duration(minutes: position * 5),
          ),
          syncState: LocalSyncState.synced,
        ),
    ];
  }

  @override
  Stream<WorkoutWithSets?> watchActiveWorkout() async* {
    yield _active;
    yield* _activeController.stream;
  }

  @override
  Stream<List<WorkoutHistoryEntry>> watchHistory() =>
      Stream.value(List.unmodifiable(_history));

  @override
  Future<WorkoutWithSets?> workoutDetail(String sessionId) async {
    if (_active?.session.id == sessionId) {
      return _active;
    }
    final index = _history.indexWhere((entry) => entry.session.id == sessionId);
    if (index < 0) {
      return null;
    }
    return WorkoutWithSets(
      session: _history[index].session,
      sets: _setsOf(index),
    );
  }

  @override
  Future<String> startWorkout({
    String? name,
    String? templateId,
    String? templateName,
  }) async {
    final id = 'demo-live-${_nextId++}';
    _publish(
      WorkoutWithSets(
        session: WorkoutInfo(
          id: id,
          name: name,
          status: WorkoutStatus.inProgress,
          startedAt: DateTime.now().toUtc(),
          templateId: templateId,
          templateName: templateName,
          syncState: LocalSyncState.synced,
        ),
        sets: const [],
      ),
    );
    return id;
  }

  @override
  Future<String> addSet(AddSetInput input) async {
    final current = _active;
    final id = 'demo-live-set-${_nextId++}';
    if (current == null) {
      return id;
    }
    _publish(
      WorkoutWithSets(
        session: current.session,
        sets: [
          ...current.sets,
          WorkoutSetEntry(
            id: id,
            exerciseId: input.exerciseId,
            exerciseName: input.exerciseName,
            position: current.sets.length,
            kind: input.kind,
            reps: input.reps,
            weightKg: input.weightKg,
            restSeconds: input.restSeconds,
            plannedReps: input.plannedReps,
            plannedWeightKg: input.plannedWeightKg,
            completedAt: DateTime.now().toUtc(),
            syncState: LocalSyncState.synced,
          ),
        ],
      ),
    );
    return id;
  }

  @override
  Future<void> deleteSet(String setId) async {
    final current = _active;
    if (current == null) {
      return;
    }
    _publish(
      WorkoutWithSets(
        session: current.session,
        sets: current.sets.where((set) => set.id != setId).toList(),
      ),
    );
  }

  @override
  Future<void> completeWorkout(String sessionId) async => _publish(null);

  @override
  Future<void> abandonWorkout(String sessionId) async => _publish(null);

  @override
  Future<void> restoreSessions() async {} // aucun serveur en démo

  void _publish(WorkoutWithSets? workout) {
    _active = workout;
    _activeController.add(workout);
  }
}
