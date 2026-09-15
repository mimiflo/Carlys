/// « Reprendre la séance ouverte, sinon en ouvrir une » — la règle, une fois.
///
/// Elle vivait recopiée dans deux widgets, chacun la décidant sur le CACHE de
/// `activeWorkoutProvider`. Or ce cache peut être en échec alors qu'une
/// séance existe : le flux Drift se TERMINE sur erreur, et le provider qui le
/// porte n'est pas `autoDispose`, donc l'échec reste collant pour toute la
/// vie de l'application — seul l'écran de séance offre un « Réessayer », et
/// on n'y arrive pas depuis la fiche d'un exercice. Les widgets lisaient
/// alors `null`, appelaient `startWorkout`, et prenaient le `StateError` du
/// domaine que personne n'attrapait : la série saisie disparaissait, sans
/// message et sans navigation, autant de fois qu'on réessayait.
library;

import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/controllers/workout_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRepository repository;
  late ProviderContainer container;
  late WorkoutActions actions;

  setUp(() {
    repository = FakeWorkoutRepository();
    container = ProviderContainer(
      overrides: [workoutRepositoryProvider.overrideWithValue(repository)],
    );
    actions = container.read(workoutActionsProvider);
  });

  tearDown(() => container.dispose());

  WorkoutWithSets seanceEnCours(String id) => WorkoutWithSets(
    session: WorkoutInfo(
      id: id,
      name: 'Séance du soir',
      status: WorkoutStatus.inProgress,
      startedAt: DateTime.utc(2026, 9, 15, 18),
      syncState: LocalSyncState.pending,
    ),
    sets: const [],
  );

  test('une séance ouverte est REPRISE, aucune seconde n’est créée', () async {
    repository.active = seanceEnCours('seance-du-soir');

    expect(await actions.currentOrStart(), 'seance-du-soir');
    // `startWorkout` de la doublure pose l'identifiant `fake-session` : le
    // voir ici voudrait dire qu'une seconde séance a été ouverte.
    expect(repository.active?.session.id, 'seance-du-soir');
  });

  test('sans séance ouverte, une séance est créée', () async {
    expect(await actions.currentOrStart(), 'fake-session');
    expect(repository.active?.session.status, WorkoutStatus.inProgress);
  });

  test(
    'le cache du provider est en échec, la base dit vrai : on reprend',
    () async {
      // LE scénario du défaut. La séance existe ; c'est la lecture observée
      // par l'écran qui est morte. Le domaine refuserait d'en ouvrir une
      // seconde — et refusait, en perdant le geste.
      repository.active = seanceEnCours('seance-du-soir');
      repository.startFailure = StateError('Une séance est déjà en cours.');

      expect(await actions.currentOrStart(), 'seance-du-soir');
      // Le refus n'a même pas eu à se produire : la lecture de la base a
      // tranché avant. Le `startFailure` est donc toujours armé.
      expect(repository.startFailure, isNotNull);
    },
  );

  test(
    'course : une séance apparaît entre la lecture et l’ouverture',
    () async {
      // L'accueil, le coach ou un modèle peuvent ouvrir une séance pendant
      // qu'on saisit la sienne. `startWorkout` lève alors, et le geste ne
      // doit pas être perdu pour autant : on rejoint la séance apparue.
      repository.startFailure = StateError('Une séance est déjà en cours.');
      var relu = false;
      repository.onStartFailed = () {
        relu = true;
        repository.active = seanceEnCours('seance-de-quelqu-un-d-autre');
      };

      expect(await actions.currentOrStart(), 'seance-de-quelqu-un-d-autre');
      expect(relu, isTrue);
    },
  );

  test(
    'refus sans séance à rejoindre : l’erreur remonte, elle ne se tait pas',
    () async {
      // Contre-épreuve du rattrapage : si rien n'explique le refus, on ne
      // fabrique pas un identifiant et on ne rend pas la main en silence.
      repository.startFailure = StateError('Une séance est déjà en cours.');

      await expectLater(actions.currentOrStart(), throwsStateError);
    },
  );

  test('addSetToCurrentOrStart pose la série sur la séance retenue', () async {
    repository.active = seanceEnCours('seance-du-soir');

    final sessionId = await actions.addSetToCurrentOrStart(
      (id) => AddSetInput(
        sessionId: id,
        exerciseName: 'Développé couché',
        reps: 8,
        weightKg: 60,
      ),
    );

    expect(sessionId, 'seance-du-soir');
    expect(repository.addedSets, hasLength(1));
    expect(repository.addedSets.single.sessionId, 'seance-du-soir');
    expect(repository.addedSets.single.reps, 8);
  });
}
