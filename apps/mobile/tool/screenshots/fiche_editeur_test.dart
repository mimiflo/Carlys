// Captures de la fiche exercice et de l'éditeur de séance (maquettes
// d'octobre 2026), montées seules sur un jeu réaliste — un développé couché
// photographié, ses records, ses muscles et ses étapes.
//
//   flutter test tool/screenshots/fiche_editeur_test.dart --update-goldens
//
// Harnais de test rangé hors de test/ (la CI ne compare pas ces rendus) :
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:carlys_mobile/core/media/remote_image.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/presentation/providers/exercise_catalog_providers.dart';
import 'package:carlys_mobile/features/exercises/presentation/screens/exercise_detail_screen.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/presentation/screens/template_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_exercises_repository.dart';
import '../../test/support/fake_workout_repository.dart';
import '../../test/support/in_memory_workout_template_repository.dart';
import 'capture_test.dart' show loadRealFonts;

const _photo = 'https://cdn.carlys.test/exercices/developpe-couche.webp';

MuscleGroupRef _muscle(String slug, String name) =>
    MuscleGroupRef(id: 'mg-$slug', slug: slug, name: name);

final _benchPress = ExerciseDetail(
  id: 'ex-dc',
  slug: 'developpe-couche',
  name: 'Développé couché',
  difficulty: ExerciseDifficulty.intermediate,
  kind: ExerciseKind.strength,
  isPremium: false,
  primaryMuscleGroup: _muscle('pectoraux', 'Pectoraux'),
  equipment: const [
    EquipmentRef(id: 'e2', slug: 'barre', name: 'Barre'),
    EquipmentRef(id: 'e7', slug: 'banc', name: 'Banc'),
  ],
  imageUrl: _photo,
  description: 'Le mouvement de base de la poussée horizontale.',
  instructions: const [
    'Pieds au sol, omoplates resserrées.',
    'Descends la barre avec contrôle vers la poitrine.',
    'Repousse la barre en gardant les poignets alignés.',
  ],
  tags: const ['poussée'],
  muscles: [
    ExerciseMuscleLink(
      muscleGroup: _muscle('pectoraux', 'Pectoraux'),
      isPrimary: true,
    ),
    ExerciseMuscleLink(
      muscleGroup: _muscle('triceps', 'Triceps'),
      isPrimary: false,
    ),
    ExerciseMuscleLink(
      muscleGroup: _muscle('epaules', 'Deltoïdes antérieurs'),
      isPrimary: false,
    ),
  ],
);

PersonalRecordEntry _record(PersonalRecordType type, double value) =>
    PersonalRecordEntry(
      id: 'pr-${type.name}',
      exerciseId: 'ex-dc',
      exerciseName: 'Développé couché',
      type: type,
      value: value,
      achievedAt: DateTime.utc(2026, 9, 28),
    );

class _BenchCatalog extends FakeExercisesRepository {
  _BenchCatalog() : super(const []);

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) async => _benchPress;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

  void telephone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> capture(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  testWidgets('fiche exercice — développé couché', (tester) async {
    telephone(tester);
    final photo = File(
      'tool/screenshots/assets/developpe-couche.jpg',
    ).readAsBytesSync();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exercisesRepositoryProvider.overrideWithValue(_BenchCatalog()),
          remoteImageProvider.overrideWith((ref, url) async => photo),
          exerciseRecordsProvider.overrideWith(
            (ref, key) => [
              _record(PersonalRecordType.maxWeight, 100),
              _record(PersonalRecordType.maxReps, 12),
              _record(PersonalRecordType.maxSetVolume, 800),
            ],
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const ExerciseDetailScreen(idOrSlug: 'developpe-couche'),
        ),
      ),
    );
    // Le décodage de la photo se fait hors de l'horloge factice : on laisse
    // l'image se poser, puis on repeint.
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'fiche-01-exercice');

    await tester.scrollUntilVisible(
      find.text('Repousse la barre en gardant les poignets alignés.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture(tester, 'fiche-02-exercice-bas');
  });

  PlannedSetInput serie(int reps, double kg) =>
      PlannedSetInput(targetReps: reps, targetWeightKg: kg, restSeconds: 90);

  testWidgets('modifier une séance — Push force', (tester) async {
    telephone(tester);
    final templates = InMemoryWorkoutTemplateRepository(
      FakeWorkoutRepository(),
      seed: [
        SaveTemplateInput(
          id: 'tpl-push',
          name: 'Push force',
          estimatedDurationMinutes: 60,
          exercises: [
            TemplateExerciseInput(
              exerciseName: 'Développé couché',
              sets: [for (var i = 0; i < 4; i++) serie(8, 80)],
            ),
            TemplateExerciseInput(
              exerciseName: 'Développé épaules',
              sets: [for (var i = 0; i < 3; i++) serie(10, 40)],
            ),
            TemplateExerciseInput(
              exerciseName: 'Extension triceps à la poulie',
              sets: [for (var i = 0; i < 3; i++) serie(10, 25)],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutTemplateRepositoryProvider.overrideWithValue(templates),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const TemplateEditorScreen(templateId: 'tpl-push'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Développé couché'));
    await tester.pumpAndSettle();
    await capture(tester, 'editeur-01-modifier-seance');

    await tester.scrollUntilVisible(
      find.text('Ajouter un exercice'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture(tester, 'editeur-02-modifier-seance-bas');
  });
}
