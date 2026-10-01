import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/data/datasources/workout_template_local_data_source.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un modèle RAPATRIÉ du serveur (nouveau téléphone, autre appareil) doit
/// se relire tel que le serveur l'a servi. La réécriture du contenu perdait
/// la durée et la distance cibles des séries de cardio : une course de
/// 20 min sur 5 km revenait sans objectif (constaté le 1er octobre 2026).
void main() {
  late AppDatabase db;
  late WorkoutTemplateLocalDataSource local;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = WorkoutTemplateLocalDataSource(db);
  });

  tearDown(() => db.close());

  test(
    'le contenu réécrit garde TOUTES les cibles, cardio comprises',
    () async {
      final modele = WorkoutTemplateDetail(
        info: WorkoutTemplateInfo(
          id: 'cardio',
          name: 'Cardio',
          exercisesCount: 1,
          plannedSetsCount: 2,
          previewExerciseNames: const ['Course'],
          updatedAt: DateTime.utc(2026, 10),
          syncState: LocalSyncState.synced,
        ),
        exercises: const [
          TemplateExerciseEntry(
            id: 'ligne-course',
            exerciseName: 'Course',
            position: 0,
            sets: [
              PlannedSet(
                id: 'serie-1',
                position: 0,
                targetDurationSeconds: 1200,
                targetDistanceMeters: 5000,
                restSeconds: 90,
              ),
              PlannedSet(
                id: 'serie-2',
                position: 1,
                targetReps: 8,
                targetWeightKg: 60,
              ),
            ],
          ),
        ],
      );
      await local.upsertHeader(
        template: modele,
        updatedAt: DateTime.utc(2026, 10),
        syncStatus: 'synced',
      );

      await local.replaceContent(modele);

      final relu = await local.detail('cardio');
      final series = relu!.exercises.single.sets;
      expect(series.first.targetDurationSeconds, 1200);
      expect(series.first.targetDistanceMeters, 5000);
      expect(series.first.restSeconds, 90);
      expect(series.last.targetReps, 8);
      expect(series.last.targetWeightKg, 60);
    },
  );
}
