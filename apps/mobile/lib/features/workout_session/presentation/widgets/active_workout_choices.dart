import '../../../workout_template/presentation/controllers/session_guidance.dart';
import '../../domain/entities/workout.dart';
import 'exercise_picker_sheet.dart';

/// Ce que la séance active DÉDUIT quand personne ne le dit explicitement :
/// sur quel exercice on est, et combien de repos annoncer.
///
/// Sorti du corps de la séance parce que ce sont des décisions, pas du
/// dessin : elles se lisent et se vérifient sans monter un écran.

/// Repos appliqué quand ni le programme ni une série précédente n'en fixe un.
const int defaultRestSeconds = 90;

/// Exercice en cours : celui explicitement choisi, sinon celui que le
/// programme propose, sinon celui de la dernière série enregistrée.
PickedExercise? currentExercise({
  required List<WorkoutSetEntry> sets,
  required SessionGuidance? guidance,
  required PickedExercise? picked,
}) {
  if (picked != null) {
    return picked;
  }
  final planned = guidance?.exerciseName;
  if (planned != null) {
    return PickedExercise(name: planned, exerciseId: guidance?.exerciseId);
  }
  if (sets.isEmpty) {
    return null;
  }
  final last = sets.last;
  return PickedExercise(name: last.exerciseName, exerciseId: last.exerciseId);
}

/// Repos de la série précédente du même exercice, à défaut le repos type.
int lastRestSeconds(List<WorkoutSetEntry> exerciseSets) {
  for (final set in exerciseSets.reversed) {
    final rest = set.restSeconds;
    if (rest != null) {
      return rest;
    }
  }
  return defaultRestSeconds;
}
