import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'objectif d'entraînement : huit objectifs distincts, un fil serveur
/// tolérant — jamais un objectif deviné.
void main() {
  test('huit objectifs, wires uniques, textes complets', () {
    expect(TrainingGoal.values, hasLength(8));
    final wires = TrainingGoal.values.map((goal) => goal.wire).toSet();
    expect(wires.length, TrainingGoal.values.length);
    for (final goal in TrainingGoal.values) {
      expect(goal.label.trim(), isNotEmpty, reason: goal.wire);
      expect(goal.description.trim(), isNotEmpty, reason: goal.wire);
    }
  });

  test('un wire inconnu rend null : jamais un objectif deviné', () {
    expect(TrainingGoal.fromWire('TRIATHLON'), isNull);
    expect(TrainingGoal.fromWire(null), isNull);
    expect(TrainingGoal.fromWire('HYROX'), TrainingGoal.hyrox);
    expect(TrainingGoal.fromWire('FAT_LOSS'), TrainingGoal.fatLoss);
  });

  test(
    'aucun wire ne recoupe l’objectif NUTRITIONNEL : deux axes, deux enums',
    () {
      // `MAINTAIN` est le maintien nutritionnel ; l'entraînement dit
      // `MAINTENANCE`. Un wire partagé inviterait à confondre les colonnes.
      const nutritionWires = {'LOSE_WEIGHT', 'MAINTAIN', 'GAIN_MUSCLE'};
      for (final goal in TrainingGoal.values) {
        expect(nutritionWires.contains(goal.wire), isFalse, reason: goal.wire);
      }
    },
  );
}
