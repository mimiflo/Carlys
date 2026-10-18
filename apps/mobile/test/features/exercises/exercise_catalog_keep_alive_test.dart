import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/presentation/providers/exercise_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercises_repository.dart';

/// En séance, la feuille « Choisir un exercice » s'ouvre à chaque mouvement
/// ajouté ; les filtres et le matériel, à chaque écran qui les montre. Le
/// catalogue ne bouge pas d'une ouverture à l'autre : relu à CHAQUE
/// ouverture, il coûtait une requête et un indicateur de chargement à
/// chaque fois. Gardé dix minutes, puis relu.
void main() {
  late FakeExercisesRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeExercisesRepository(const []);
    container = ProviderContainer(
      overrides: [exercisesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  /// Une ouverture : l'écran lit, puis se ferme — l'auto-disposition suit.
  Future<void> open<T>(
    WidgetTester tester,
    AutoDisposeFutureProvider<T> provider,
  ) async {
    final subscription = container.listen(provider.future, (_, _) {});
    await subscription.read();
    subscription.close();
    // L'auto-disposition passe par la boucle d'événements.
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('cinq ouvertures, une requête par lecture', (tester) async {
    for (var i = 0; i < 5; i++) {
      await open(tester, exerciseSearchProvider(''));
      await open(tester, muscleGroupsProvider);
      await open(tester, equipmentCatalogProvider);
    }

    expect(repository.listCalls, 1);
    expect(repository.muscleGroupsCalls, 1);
    expect(repository.equipmentCalls, 1);
    // La garde est une minuterie : le banc refuse qu'elle survive au test.
    await tester.pump(catalogKeepAlive);
  });

  testWidgets('passé dix minutes, la lecture suivante relit', (tester) async {
    await open(tester, exerciseSearchProvider(''));
    await open(tester, muscleGroupsProvider);
    await tester.pump(const Duration(minutes: 11));
    await open(tester, exerciseSearchProvider(''));
    await open(tester, muscleGroupsProvider);

    expect(repository.listCalls, 2);
    expect(repository.muscleGroupsCalls, 2);
    await tester.pump(catalogKeepAlive);
  });

  testWidgets('une recherche tapée n’est pas gardée', (tester) async {
    await open(tester, exerciseSearchProvider('squat'));
    await open(tester, exerciseSearchProvider('squat'));

    expect(repository.listCalls, 2);
  });
}
