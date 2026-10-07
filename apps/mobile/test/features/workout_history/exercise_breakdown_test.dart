import 'package:carlys_mobile/features/workout_history/domain/services/exercise_breakdown.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSetEntry serie(
  int position,
  String name, {
  String? exerciseId,
  int? reps,
  double? kg,
  int? seconds,
}) => WorkoutSetEntry(
  id: 's$position',
  exerciseId: exerciseId,
  exerciseName: name,
  position: position,
  kind: SetKind.normal,
  reps: reps,
  weightKg: kg,
  durationSeconds: seconds,
  completedAt: DateTime.utc(2026, 10, 7),
  syncState: LocalSyncState.synced,
);

void main() {
  test(
    'une carte par exercice, dans l’ordre où il apparaît — superset compris',
    () {
      final groupes = breakdownByExercise([
        serie(3, 'Développé couché', exerciseId: 'dc', reps: 8, kg: 80),
        serie(1, 'Développé couché', exerciseId: 'dc', reps: 8, kg: 80),
        serie(2, 'Tirage', exerciseId: 'ti', reps: 10, kg: 50),
      ]);

      expect(groupes.map((g) => g.name), ['Développé couché', 'Tirage']);
      expect(groupes.first.sets.map((s) => s.position), [1, 3]);
      expect(groupes.first.volumeKg, 1280);
    },
  );

  test('un exercice libre se reconnaît à son nom', () {
    final groupes = breakdownByExercise([
      serie(1, 'Pompes', reps: 20),
      serie(2, 'Pompes', reps: 15),
      serie(3, 'Gainage', seconds: 60),
    ]);

    expect(groupes, hasLength(2));
    expect(groupes.first.volumeKg, 0, reason: 'sans charge, pas de volume');
    expect(groupes.last.timed, isTrue);
    expect(groupes.last.totalSeconds, 60);
  });

  test('la série qui résume : la plus lourde, puis la plus répétée', () {
    final exercice = breakdownByExercise([
      serie(1, 'Squat', exerciseId: 'sq', reps: 10, kg: 60),
      serie(2, 'Squat', exerciseId: 'sq', reps: 5, kg: 100),
      serie(3, 'Squat', exerciseId: 'sq', reps: 6, kg: 100),
    ]).single;

    expect(exercice.topSet.id, 's3');
  });
}
