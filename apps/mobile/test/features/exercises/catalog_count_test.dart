import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/domain/repositories/exercises_repository.dart';
import 'package:carlys_mobile/features/exercises/presentation/controllers/exercise_library_controller.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_catalog_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le compteur de la bibliothèque annonce le TOTAL du serveur.
///
/// Ce que ce test garde : l'en-tête se contentait de compter les pages déjà
/// chargées et ajoutait « + ». Le groupe « Épaules », fort de trente-huit
/// mouvements, s'annonçait donc « 12+ ».
ExerciseSummary _exercise(String id) => ExerciseSummary(
      id: id,
      slug: id,
      name: 'Mouvement $id',
      difficulty: ExerciseDifficulty.beginner,
      kind: ExerciseKind.strength,
      isPremium: false,
      primaryMuscleGroup: null,
      equipment: const [],
      imageUrl: null,
    );

Widget _harness(ExerciseLibraryState state) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: ExerciseCatalogList(state: state)),
      ),
    );

void main() {
  final items = [for (var i = 0; i < 6; i++) _exercise('e$i')];

  testWidgets('avec un total : le nombre réel, sans « + »', (tester) async {
    await tester.pumpWidget(
      _harness(
        ExerciseLibraryState(
          items: items,
          filters: const ExercisesFilters(),
          hasMore: true,
          nextCursor: 'e5',
          isLoadingMore: false,
          total: 38,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('38 mouvements'), findsOneWidget);
  });

  testWidgets('sans total : le repli « N+ » reste', (tester) async {
    await tester.pumpWidget(
      _harness(
        ExerciseLibraryState(
          items: items,
          filters: const ExercisesFilters(),
          hasMore: true,
          nextCursor: 'e5',
          isLoadingMore: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('6+ mouvements'), findsOneWidget);
  });
}
