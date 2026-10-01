import 'dart:math';

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/datasources/workout_session_remote_data_source.dart';
import 'package:carlys_mobile/features/workout_session/data/dto/workout_session_dtos.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_session_downloader.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:drift/drift.dart'
    show
        ApplyInterceptor,
        BatchedStatements,
        QueryExecutor,
        QueryInterceptor,
        Value;
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
  _FakeRemote(
    this.sessions, {
    this.listedRevisions = const {},
    this.paged = false,
    this.failingDetail,
  });

  /// Détail que le serveur refuse de servir (500, DTO illisible).
  final String? failingDetail;

  final List<RemoteWorkoutSession> sessions;

  /// Révision servie par la LISTE quand elle diffère du détail : une
  /// écriture tombée entre les deux lectures.
  final Map<String, int> listedRevisions;
  final List<String> detailCalls = [];
  int listCalls = 0;

  /// Pages bornées par `limit`, comme le serveur ; sinon tout d'un coup.
  final bool paged;
  final List<int?> limits = [];

  /// Détails en vol en même temps, au plus fort.
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<WorkoutSessionsPage> list({String? cursor, int? limit}) async {
    listCalls++;
    limits.add(limit);
    if (paged) {
      final from = int.parse(cursor ?? '0');
      final to = from + limit!;
      return WorkoutSessionsPage(
        items: [
          for (final session in sessions.skip(from).take(limit))
            RemoteWorkoutSessionRef(
              id: session.id,
              startedAt: session.startedAt,
              revision: session.revision,
            ),
        ],
        hasMore: to < sessions.length,
        nextCursor: '$to',
      );
    }
    return WorkoutSessionsPage(
      items: sessions
          .map(
            (session) => RemoteWorkoutSessionRef(
              id: session.id,
              startedAt: session.startedAt,
              revision: listedRevisions[session.id] ?? session.revision,
            ),
          )
          .toList(),
      hasMore: false,
    );
  }

  @override
  Future<RemoteWorkoutSession> detail(String sessionId) async {
    detailCalls.add(sessionId);
    maxInFlight = max(maxInFlight, ++inFlight);
    await Future<void>.delayed(Duration.zero);
    inFlight--;
    if (sessionId == failingDetail) throw StateError('détail illisible');
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

/// Séance close n° [index], telle que le serveur la sert à la révision
/// [revision] : une série, deux prévisions.
RemoteWorkoutSession _closedSession(
  int index, {
  int? revision = 3,
  int reps = 8,
}) {
  final id = 'seance-$index';
  final startedAt = DateTime.utc(2026, 6, 1).add(Duration(days: index));
  return RemoteWorkoutSession(
    id: id,
    status: 'COMPLETED',
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(hours: 1)),
    revision: revision,
    sets: [
      RemoteWorkoutSet(
        id: '$id-serie',
        exerciseName: 'Tractions',
        position: 0,
        kind: 'NORMAL',
        reps: reps,
        completedAt: startedAt.add(const Duration(minutes: 5)),
      ),
    ],
    plan: [
      for (var set = 0; set < 2; set++)
        RemoteSessionPlanItem(
          id: '$id-prevu-$set',
          exercisePosition: 0,
          exerciseName: 'Tractions',
          setPosition: set,
          kind: 'NORMAL',
          targetReps: 8,
          skipped: false,
        ),
    ],
  );
}

/// Compte les ÉCRITURES que Drift envoie réellement à SQLite (insertions,
/// mises à jour, suppressions, et chaque instruction d'un lot) : la mesure
/// du rapatriement, que le nombre de téléchargements ne dit qu'à moitié.
class _WriteCounter extends QueryInterceptor {
  int writes = 0;

  @override
  Future<int> runInsert(QueryExecutor e, String s, List<Object?> a) {
    writes++;
    return super.runInsert(e, s, a);
  }

  @override
  Future<int> runUpdate(QueryExecutor e, String s, List<Object?> a) {
    writes++;
    return super.runUpdate(e, s, a);
  }

  @override
  Future<int> runDelete(QueryExecutor e, String s, List<Object?> a) {
    writes++;
    return super.runDelete(e, s, a);
  }

  @override
  Future<void> runBatched(QueryExecutor e, BatchedStatements statements) {
    writes += statements.arguments.length;
    return super.runBatched(e, statements);
  }
}

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine engine;
  late WorkoutTemplateRepositoryImpl templates;
  late _WriteCounter counter;

  setUp(() {
    counter = _WriteCounter();
    db = AppDatabase(NativeDatabase.memory().interceptWith(counter));
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

  test('une série supprimée hors ligne NE RESSUSCITE PAS', () async {
    // LE PIÈGE. Le rapatriement efface les séries `synced` et réinsère celles
    // du serveur ; sa protection tient toute entière dans le commentaire du
    // code : « Une série jamais acquittée n'est pas à lui : elle reste »,
    // c'est-à-dire `syncStatus != 'synced'`. Or une suppression posait la
    // pierre tombale SANS repasser la ligne en `pending` : le rapatriement
    // l'effaçait comme une ligne du serveur, et le serveur — qui a toujours
    // la série puisque le DELETE n'est jamais parti — la réinsérait vivante.
    final serveur = [
      RemoteWorkoutSet(
        id: 'set-1',
        exerciseName: 'Développé couché',
        position: 0,
        kind: 'NORMAL',
        reps: 8,
        completedAt: DateTime.utc(2026, 8, 8, 17, 5),
      ),
    ];
    await repositoryOn(
      _FakeRemote([_pushSession(sets: serveur)]),
    ).restoreSessions();
    expect(await db.select(db.localWorkoutSets).get(), hasLength(1));

    // Hors ligne : la suppression reste en file, le serveur garde la série.
    api.networkDown = true;
    await repositoryOn(_FakeRemote([])).deleteSet('set-1');

    // Redémarrage : le rapatriement repasse, le serveur sert toujours set-1.
    await repositoryOn(
      _FakeRemote([_pushSession(sets: serveur)]),
    ).restoreSessions();

    final restantes = await db.select(db.localWorkoutSets).get();
    expect(
      restantes.where((row) => !row.deleted),
      isEmpty,
      reason: 'la série supprimée est revenue vivante après le rapatriement',
    );
  });

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

  /// LA RÉVISION DE SÉANCE (décision D4 du 27 septembre 2026).
  ///
  /// Chaque lancement relisait et réécrivait les 60 séances rapatriées,
  /// identiques ou non : 60 téléchargements et des centaines d'écritures
  /// Drift pour rien. L'API sert désormais une révision entière par séance,
  /// qui monte à chaque écriture validée : même révision, même séance.
  group('révision servie par l’API', () {
    final soixante = [
      for (var i = 0; i < WorkoutSessionDownloader.restoredSessionsMax; i++)
        _closedSession(i),
    ];

    test(
      '60 séances inchangées : aucun téléchargement, aucune écriture',
      () async {
        final premier = _FakeRemote(soixante);
        await repositoryOn(premier).restoreSessions();
        expect(premier.detailCalls, hasLength(60));
        final ecrituresDuPremier = counter.writes;
        expect(ecrituresDuPremier, greaterThan(0));

        counter.writes = 0;
        final second = _FakeRemote(soixante);
        await repositoryOn(second).restoreSessions();

        // (téléchargements, écritures Drift) du second lancement. Avant la
        // révision : les 60 détails relus et toutes les séances réécrites.
        expect((second.detailCalls.length, counter.writes), (0, 0));
        // La liste, elle, se lit toujours : c'est elle qui porte la révision.
        expect(second.listCalls, 1);
      },
    );

    test('pas une séance de trop demandée, et les détails par lots', () async {
      final remote = _FakeRemote([
        for (var i = 0; i < 100; i++) _closedSession(i),
      ], paged: true);
      await repositoryOn(remote).restoreSessions();

      // 50 puis les 10 qui manquent au plafond, pas 50 puis 50.
      expect(remote.limits, [50, 10]);
      expect(remote.detailCalls, hasLength(60));
      expect(remote.maxInFlight, inInclusiveRange(2, 6));
      expect(await db.select(db.localWorkoutSessions).get(), hasLength(60));
    });

    test(
      'une purge en vol arrête tout : ni lot téléchargé, ni écriture',
      () async {
        var answers = 0;
        final remote = _FakeRemote(soixante);
        // Vrai au premier lot, faux dès la première écriture.
        await repositoryOn(
          remote,
        ).restoreSessions(shouldContinue: () => answers++ == 0);

        expect(remote.detailCalls, hasLength(6));
        expect(await db.select(db.localWorkoutSessions).get(), isEmpty);
      },
    );

    test('un détail en échec n’empêche pas d’écrire ceux d’avant', () async {
      final remote = _FakeRemote(soixante, failingDetail: 'seance-2');

      await expectLater(
        repositoryOn(remote).restoreSessions(),
        throwsA(isA<StateError>()),
      );
      final ids = (await db.select(db.localWorkoutSessions).get()).map(
        (row) => row.id,
      );
      expect(ids, unorderedEquals(['seance-0', 'seance-1']));
    });

    test('une séance modifiée ailleurs est reprise, et elle seule', () async {
      await repositoryOn(_FakeRemote(soixante)).restoreSessions();

      // Sur l'autre appareil, une correction de répétitions : la révision
      // monte, rien d'autre dans la liste ne le dirait.
      final corrigee = _closedSession(7, revision: 4, reps: 12);
      final remote = _FakeRemote([
        for (final session in soixante)
          session.id == corrigee.id ? corrigee : session,
      ]);
      await repositoryOn(remote).restoreSessions();

      expect(remote.detailCalls, ['seance-7']);
      final serie = await (db.select(
        db.localWorkoutSets,
      )..where((row) => row.id.equals('seance-7-serie'))).getSingle();
      expect(serie.reps, 12);
      final seance = await (db.select(
        db.localWorkoutSessions,
      )..where((row) => row.id.equals('seance-7'))).getSingle();
      expect(seance.revision, 4);
    });

    test('une séance en attente d’envoi n’est jamais écrasée, même si le '
        'serveur a bougé', () async {
      await repositoryOn(_FakeRemote([_closedSession(0)])).restoreSessions();
      // Une série ajoutée ici, pas encore acquittée (`pending` par défaut).
      await db
          .into(db.localWorkoutSets)
          .insert(
            LocalWorkoutSetsCompanion.insert(
              id: 'serie-locale',
              sessionId: 'seance-0',
              exerciseName: 'Tractions',
              position: 1,
              completedAt: DateTime.utc(2026, 6, 1, 0, 10),
            ),
          );

      final remote = _FakeRemote([_closedSession(0, revision: 9, reps: 5)]);
      await repositoryOn(remote).restoreSessions();

      expect(remote.detailCalls, isEmpty);
      final series = await db.select(db.localWorkoutSets).get();
      expect(series.map((row) => row.id), contains('serie-locale'));
      expect(
        series.singleWhere((row) => row.id == 'seance-0-serie').reps,
        8,
        reason: 'la version serveur a écrasé une séance en attente d’envoi',
      );
    });

    test('la révision retenue est celle du DÉTAIL, lu en dernier', () async {
      // Une écriture tombe entre la liste (3) et le détail (4) : la copie
      // locale est celle de la révision 4, c'est donc 4 qu'on retient.
      await repositoryOn(
        _FakeRemote(
          [_closedSession(0, revision: 4)],
          listedRevisions: {'seance-0': 3},
        ),
      ).restoreSessions();

      final remote = _FakeRemote([_closedSession(0, revision: 4)]);
      await repositoryOn(remote).restoreSessions();

      expect(remote.detailCalls, isEmpty);
    });

    test('sans révision (serveur plus ancien), on retélécharge', () async {
      final ancien = [_closedSession(0, revision: null)];
      await repositoryOn(_FakeRemote(ancien)).restoreSessions();

      final remote = _FakeRemote(ancien);
      await repositoryOn(remote).restoreSessions();

      expect(remote.detailCalls, ['seance-0']);
    });

    test('une séance née ici, jamais rapatriée, est relue une fois', () async {
      // Créée sur cet appareil puis acquittée : sa révision locale est nulle,
      // la copie n'a jamais été comparée au serveur.
      await db
          .into(db.localWorkoutSessions)
          .insert(
            LocalWorkoutSessionsCompanion.insert(
              id: 'seance-0',
              status: 'COMPLETED',
              startedAt: DateTime.utc(2026, 6, 1),
              syncStatus: const Value('synced'),
            ),
          );

      final remote = _FakeRemote([_closedSession(0)]);
      await repositoryOn(remote).restoreSessions();

      expect(remote.detailCalls, ['seance-0']);
    });
  });
}
