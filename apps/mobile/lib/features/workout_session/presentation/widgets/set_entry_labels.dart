import '../../../../core/utilities/formatting.dart';
import '../../domain/entities/workout.dart';

// Les deux phrases de la carte de série, en fonctions pures : elles se
// testent sans widget, et la carte reste sous son plafond de lignes.

/// « Objectif : 8 répétitions à 60 kg » ; une cible partielle reste lisible
/// (« Objectif : 8 répétitions », « Objectif : 60 kg », « Objectif : 45 s »)
/// — un modèle sans charge prévue est légitime. Une PROPOSITION, jamais une
/// contrainte. `null` hors programme.
String? setObjectiveLabel({int? reps, double? weightKg, int? durationSeconds}) {
  final repsLabel = reps == null
      ? null
      : '${formatThousands(reps)} répétition${reps > 1 ? 's' : ''}';
  if (repsLabel != null && weightKg != null) {
    return 'Objectif : $repsLabel à ${formatDecimal(weightKg)} kg';
  }
  if (repsLabel != null) {
    return 'Objectif : $repsLabel';
  }
  if (weightKg != null) {
    return 'Objectif : ${formatDecimal(weightKg)} kg';
  }
  if (durationSeconds != null) {
    final duration = formatDuration(durationSeconds);
    return 'Objectif : ${duration.value} ${duration.unit}';
  }
  return null;
}

/// « Dernière série : 80 kg × 8 reps » — la performance précédente, dans son
/// unité (« Dernière série : 45 s » pour un gainage). `null` sans historique.
String? previousSetLabel(WorkoutSetEntry? previous) {
  if (previous == null) {
    return null;
  }
  final weight = previous.weightKg;
  final reps = previous.reps;
  if (weight != null && reps != null) {
    return 'Dernière série : ${formatDecimal(weight)} kg × '
        '${formatThousands(reps)} reps';
  }
  final seconds = previous.durationSeconds;
  if (seconds != null) {
    final duration = formatDuration(seconds);
    return 'Dernière série : ${duration.value} ${duration.unit}';
  }
  return null;
}
