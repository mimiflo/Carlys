import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/domain/repositories/exercises_repository.dart';
import 'package:carlys_mobile/features/exercises/presentation/controllers/exercise_library_controller.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_catalog_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le fondu du bas du catalogue se PEINT par-dessus la liste, il ne la
/// masque pas. Un `ShaderMask` sur toute la liste la rendait dans une couche
/// hors écran à chaque image de défilement, pour n'en fondre que le bas.
void main() {
  testWidgets('aucune couche hors écran sous la liste qui défile', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExerciseCatalogList(
              state: ExerciseLibraryState(
                items: [
                  for (var i = 0; i < 12; i++)
                    ExerciseSummary(
                      id: 'e$i',
                      slug: 'e$i',
                      name: 'Mouvement $i',
                      difficulty: ExerciseDifficulty.beginner,
                      kind: ExerciseKind.strength,
                      isPremium: false,
                      primaryMuscleGroup: null,
                      equipment: const [],
                      imageUrl: null,
                    ),
                ],
                filters: const ExercisesFilters(),
                hasMore: false,
                nextCursor: null,
                isLoadingMore: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();

    expect(tester.layers.whereType<ShaderMaskLayer>(), isEmpty);
  });
}
