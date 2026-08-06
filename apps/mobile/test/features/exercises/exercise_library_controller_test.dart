import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/presentation/controllers/exercise_library_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercises_repository.dart';

void main() {
  late FakeExercisesRepository repository;
  late ProviderContainer container;

  ProviderContainer buildContainer() {
    final providerContainer = ProviderContainer(
      overrides: [exercisesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(providerContainer.dispose);
    return providerContainer;
  }

  setUp(() {
    repository = FakeExercisesRepository([
      summary('id-1', 'Curl', group: 'biceps'),
      summary('id-2', 'Dips', group: 'triceps'),
      summary('id-3', 'Pompes', group: 'pectoraux'),
      summary('id-4', 'Squat', group: 'quadriceps'),
      summary('id-5', 'Tractions', group: 'dos'),
    ]);
    container = buildContainer();
  });

  test('charge la première page avec pagination', () async {
    final state =
        await container.read(exerciseLibraryControllerProvider.future);

    expect(state.items.map((item) => item.id), ['id-1', 'id-2']);
    expect(state.hasMore, isTrue);
    expect(state.nextCursor, 'id-2');
  });

  test('loadMore fusionne les pages sans doublon', () async {
    await container.read(exerciseLibraryControllerProvider.future);
    final controller =
        container.read(exerciseLibraryControllerProvider.notifier);

    await controller.loadMore();
    await controller.loadMore();

    final state = container.read(exerciseLibraryControllerProvider).value!;
    expect(state.items.map((item) => item.id), [
      'id-1',
      'id-2',
      'id-3',
      'id-4',
      'id-5',
    ]);
    expect(state.hasMore, isFalse);

    // Sans page suivante, loadMore ne rappelle pas l'API.
    final calls = repository.listCalls;
    await controller.loadMore();
    expect(repository.listCalls, calls);
  });

  test('la recherche est débouncée puis relance depuis la première page',
      () async {
    await container.read(exerciseLibraryControllerProvider.future);
    final controller =
        container.read(exerciseLibraryControllerProvider.notifier);

    controller.setSearch('S');
    controller.setSearch('Sq');
    controller.setSearch('Squat');
    await Future<void>.delayed(
      ExerciseLibraryController.searchDebounce + const Duration(milliseconds: 50),
    );

    final state = container.read(exerciseLibraryControllerProvider).value!;
    expect(state.items.map((item) => item.name), ['Squat']);
    // 1 chargement initial + 1 seul rechargement malgré 3 frappes.
    expect(repository.listCalls, 2);
  });

  test('filtre par difficulté transmis au repository puis réinitialisé',
      () async {
    await container.read(exerciseLibraryControllerProvider.future);
    final controller =
        container.read(exerciseLibraryControllerProvider.notifier);

    await controller.setDifficulty(ExerciseDifficulty.advanced);
    expect(repository.receivedFilters.last.difficulty,
        ExerciseDifficulty.advanced);

    await controller.setDifficulty(null);
    expect(repository.receivedFilters.last.difficulty, isNull);
  });
}
