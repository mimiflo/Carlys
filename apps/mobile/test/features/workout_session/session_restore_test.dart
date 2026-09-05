import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/datasources/workout_session_remote_data_source.dart';
import 'package:carlys_mobile/features/workout_session/data/dto/workout_session_dtos.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// **Reprise multi-appareil.**
///
/// Le scénario : une séance est lancée depuis un modèle sur un premier
/// téléphone ; sur un second, la base locale est vide. Le rapatriement doit
/// rendre la séance, ses séries **et son plan** — sans quoi le second appareil
/// affiche des séries sans objectif.
class _FakeRemote implements WorkoutSessionRemoteDataSource {
  _FakeRemote(this.sessions);

  final List<RemoteWorkoutSession> sessions;
  final List<String> detailCalls = [];
  int listCalls = 0;

  @override
  Future<WorkoutSessionsPage> list({String? cursor, int? limit}) async {
    listCalls++;
    return WorkoutSessionsPage(
      items: sessions
          .map(
            (session) => RemoteWorkoutSessionRef(
              id: session.id,
              startedAt: session.startedAt,
            ),
          )
          .toList(),
      hasMore: false,
    );
  }

  @override
  Future<RemoteWorkoutSession> detail(String sessionId) async {
    detailCalls.add(sessionId);
    return sessions.firstWhere((session) => session.id == sessionId);
  }
}

RemoteWorkoutSession _pushSession({
  String status = 'IN_PROGRESS',
  List<RemoteWorkoutSet> sets = const [],
  bool secondSkipped = false,
  String? firstDoneSetId,
}) {
  return RemoteWorkoutSession(
    id: 'session-1',
    name: 'Push force',
    status: status,
    startedAt: DateTime.utc(2026, 8, 8, 17),
    templateId: 'modele-1',
    templateName: 'Push force',
    sets: sets,
    plan: [
      RemoteSessionPlanItem(
        id: 'plan-1',
        exercisePosition: 0,
        exerciseId: 'exo-dc',
        exerciseName: 'Développé couché',
        setPosition: 0,
        kind: 'NORMAL',
        targetReps: 8,
        targetWeightKg: 70,
        restSeconds: 120,
        doneSetId: firstDoneSetId,
        skipped: false,
      ),
      RemoteSessionPlanItem(
        id: 'plan-2',
        exercisePosition: 0,
        exerciseId: 'exo-dc',
        exerciseName: 'Développé couché',
        setPosition: 1,
        kind: 'NORMAL',
        targetReps: 8,
        targetWeightKg: 70,
        restSeconds: 120,
        skipped: secondSkipped,
      ),
      const RemoteSessionPlanItem(
        id: 'plan-3',
        exercisePosition: 1,
        exerciseName: 'Dips',
        setPosition: 0,
        kind: 'NORMAL',
        targetReps: 12,
        skipped: false,
      ),
    ],
  );
}

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine engine;
  late WorkoutTemplateRepositoryImpl templates;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    engine = SyncEngine(database: db, api: api);
    templates = WorkoutTemplateRepositoryImpl(database: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  WorkoutRepositoryImpl repositoryOn(_FakeRemote remote) =>
      WorkoutRepositoryImpl(database: db, syncEngine: engine, remote: remote);

  test(
    'un appareil neuf retrouve la séance en cours AVEC ses cibles',
    () async {
      final remote = _FakeRemote([
        _pushSession(
          firstDoneSetId: 'set-1',
          sets: [
            RemoteWorkoutSet(
              id: 'set-1',
              exerciseId: 'exo-dc',
              exerciseName: 'Développé couché',
              position: 0,
              kind: 'NORMAL',
              reps: 7,
              weightKg: 70,
              plannedReps: 8,
              plannedWeightKg: 70,
              completedAt: DateTime.utc(2026, 8, 8, 17, 5),
            ),
          ],
        ),
      ]);
      final workouts = repositoryOn(remote);

      await workouts.restoreSessions();

      // 1. La séance revient telle quelle, marquée comme déjà synchronisée.
      final active = await workouts.watchActiveWorkout().first;
      expect(active, isNotNull);
      expect(active!.session.id, 'session-1');
      expect(active.session.templateName, 'Push force');
      expect(active.session.syncState, LocalSyncState.synced);
      expect(active.sets, hasLength(1));
      // La déviation reste lisible : 7 faites pour 8 prévues.
      expect(active.sets.single.reps, 7);
      expect(active.sets.single.plannedReps, 8);

      // 2. Le plan aussi — c'est précisément ce qui manquait.
      final plan = await templates.sessionPlan('session-1');
      expect(plan, isNotNull);
      expect(plan!.totalCount, 3);
      expect(plan.doneCount, 1);
      expect(plan.items.first.doneSetId, 'set-1');
      expect(plan.items.first.targetReps, 8);
      expect(plan.items.first.targetWeightKg, 70);
      // La séance reprend là où l'autre appareil l'a laissée.
      expect(plan.current!.id, 'plan-2');
      expect(plan.progressOfExercise(0), (1, 2));
    },
  );

  test('une série passée ailleurs n’est pas reproposée', () async {
    final remote = _FakeRemote([_pushSession(secondSkipped: true)]);

    await repositoryOn(remote).restoreSessions();

    final plan = await templates.sessionPlan('session-1');
    expect(plan!.items[1].skipped, isTrue);
    // Deux séries restent : la 1re du développé couché et les Dips. La série
    // passée sur l'autre appareil n'est pas reproposée ici.
    expect(plan.remainingCount, 2);
    expect(plan.nextPendingFor(exerciseName: 'Développé couché')?.id, 'plan-1');
  });

  test('une saisie locale non acquittée n’est JAMAIS écrasée', () async {
    final remote = _FakeRemote([_pushSession()]);
    // L'appareil a sa propre version de la séance, pas encore poussée.
    await db
        .into(db.localWorkoutSessions)
        .insert(
          LocalWorkoutSessionsCompanion.insert(
            id: 'session-1',
            name: const Value('Saisie locale'),
            status: 'IN_PROGRESS',
            startedAt: DateTime.utc(2026, 8, 8, 17),
          ),
        );

    await repositoryOn(remote).restoreSessions();

    final stored = await db.select(db.localWorkoutSessions).get();
    expect(stored.single.name, 'Saisie locale');
    expect(remote.detailCalls, isEmpty); // même pas téléchargée
  });

  test(
    'un « passer » encore en file protège la séance du rapatriement',
    () async {
      final remote = _FakeRemote([_pushSession()]);
      // Séance et séries acquittées, mais un « passer » attend son tour :
      // hors ligne, l'opération reste en file.
      await repositoryOn(_FakeRemote([_pushSession()])).restoreSessions();
      api.networkDown = true;
      await templates.skipPlanItem('plan-2');

      await repositoryOn(remote).restoreSessions();

      final plan = await templates.sessionPlan('session-1');
      // Le serveur ne l'a pas remis à zéro.
      expect(plan!.items[1].skipped, isTrue);
      expect(remote.detailCalls, isEmpty);
    },
  );

  test('une séance déjà acquittée est rafraîchie sans conflit', () async {
    await repositoryOn(_FakeRemote([_pushSession()])).restoreSessions();

    // Le serveur a progressé entre-temps (série ajoutée sur l'autre appareil).
    final remote = _FakeRemote([
      _pushSession(
        firstDoneSetId: 'set-1',
        sets: [
          RemoteWorkoutSet(
            id: 'set-1',
            exerciseName: 'Développé couché',
            position: 0,
            kind: 'NORMAL',
            reps: 8,
            completedAt: DateTime.utc(2026, 8, 8, 17, 5),
          ),
        ],
      ),
    ]);
    await repositoryOn(remote).restoreSessions();

    expect(remote.detailCalls, ['session-1']);
    final plan = await templates.sessionPlan('session-1');
    expect(plan!.doneCount, 1);
    // Aucun doublon : le plan est remplacé, pas empilé.
    expect(await db.select(db.localSessionPlanItems).get(), hasLength(3));
    expect(await db.select(db.localWorkoutSets).get(), hasLength(1));
  });

  test('l’historique revient aussi, séance terminée comprise', () async {
    final remote = _FakeRemote([_pushSession(status: 'COMPLETED')]);

    await repositoryOn(remote).restoreSessions();

    final history = await repositoryOn(remote).watchHistory().first;
    expect(history, hasLength(1));
    expect(history.single.session.status, WorkoutStatus.completed);
  });

  test(
    'la séance en cours DE CET APPAREIL prime sur celle du serveur',
    () async {
      final remote = _FakeRemote([_pushSession()]);
      // L'utilisateur a démarré une séance libre ici, déjà acquittée.
      await db
          .into(db.localWorkoutSessions)
          .insert(
            LocalWorkoutSessionsCompanion.insert(
              id: 'session-locale',
              name: const Value('Séance libre'),
              status: 'IN_PROGRESS',
              startedAt: DateTime.utc(2026, 8, 8, 18),
              syncStatus: const Value('synced'),
            ),
          );

      await repositoryOn(remote).restoreSessions();

      // Au plus une séance en cours : la distante attend son tour sur le
      // serveur, elle n'est pas perdue.
      final active = await db.select(db.localWorkoutSessions).get();
      expect(active.map((row) => row.id), ['session-locale']);
    },
  );

  test('sans source distante, le rapatriement ne fait rien', () async {
    final workouts = WorkoutRepositoryImpl(database: db, syncEngine: engine);

    await workouts.restoreSessions();

    expect(await db.select(db.localWorkoutSessions).get(), isEmpty);
  });
}
