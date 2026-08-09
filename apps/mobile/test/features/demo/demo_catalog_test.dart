import 'package:carlys_mobile/core/media/remote_image_cache.dart';
import 'package:carlys_mobile/demo/demo_catalog.dart';
import 'package:carlys_mobile/demo/demo_repositories.dart';
import 'package:carlys_mobile/features/exercises/domain/repositories/exercises_repository.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Le catalogue de la démonstration est ENGENDRÉ depuis le seed de l'API
/// (`pnpm --filter @carlys/api demo:catalog`). Ces tests vérifient le bout de
/// chaîne côté application : l'asset est bien déclaré, il se lit, et chaque
/// vignette annoncée existe vraiment dans le paquet.
///
/// Ils gardent la panne signalée sur l'APK de démo : onze exercices affichés
/// au lieu de cinquante-cinq, et aucune vignette.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le catalogue embarqué se lit et couvre tout le seed', () async {
    final catalog = await loadDemoCatalog();

    expect(catalog.exercises.length, greaterThanOrEqualTo(50));
    expect(catalog.muscleGroups, isNotEmpty);
    expect(catalog.equipment, isNotEmpty);
  });

  test('aucun groupe musculaire vide n’est proposé', () async {
    final catalog = await loadDemoCatalog();
    final withExercises = catalog.exercises
        .map((exercise) => exercise.primaryMuscleGroup?.slug)
        .nonNulls
        .toSet();

    for (final group in catalog.muscleGroups) {
      expect(
        withExercises,
        contains(group.slug),
        reason: 'le groupe ${group.slug} s’ouvrirait sur une liste vide',
      );
    }
  });

  test('chaque vignette annoncée existe dans le paquet', () async {
    final catalog = await loadDemoCatalog();
    final illustrated =
        catalog.exercises.where((exercise) => exercise.imageUrl != null);

    expect(illustrated, isNotEmpty, reason: 'la démo doit rester illustrée');
    for (final exercise in illustrated) {
      final url = exercise.imageUrl!;
      expect(url, startsWith(assetImageScheme));
      // Lève si l'image manque : c'est exactement le défaut qu'on traque.
      final bytes =
          await rootBundle.load(url.substring(assetImageScheme.length));
      expect(bytes.lengthInBytes, greaterThan(0), reason: url);
    }
  });

  test('le dépôt de démonstration pagine sur le catalogue engendré', () async {
    final repository = DemoExercisesRepository();
    final catalog = await loadDemoCatalog();

    final first = await repository.list();
    expect(first.items, isNotEmpty);
    expect(first.hasMore, isTrue);

    // On déroule la pagination jusqu'au bout : tous les exercices doivent
    // être atteignables, pas seulement la première page.
    final seen = <String>{...first.items.map((exercise) => exercise.id)};
    var cursor = first.nextCursor;
    while (cursor != null) {
      final page = await repository.list(cursor: cursor);
      seen.addAll(page.items.map((exercise) => exercise.id));
      cursor = page.nextCursor;
    }
    expect(seen.length, catalog.exercises.length);
  });

  test('les filtres du dépôt portent sur le catalogue entier', () async {
    final repository = DemoExercisesRepository();
    final groups = await repository.muscleGroups();

    final page = await repository.list(
      filters: ExercisesFilters(muscleGroupSlug: groups.first.slug),
    );

    expect(page.items, isNotEmpty);
    expect(
      page.items.every(
        (exercise) => exercise.primaryMuscleGroup?.slug == groups.first.slug,
      ),
      isTrue,
    );
  });
}
