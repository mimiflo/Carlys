import '../../../../core/utilities/formatting.dart';
import '../../domain/entities/workout.dart';

// Les libellés d’une série, partagés par le tableau de la séance en cours et
// celui du bilan.

/// Ce qu'une série montre, DANS SON UNITÉ.
///
/// Une série chronométrée affichée « — kg × — » se lit comme une série
/// ratée, alors qu'elle est complète : c'est juste qu'elle ne se compte pas
/// en charge. On lit donc d'abord ce qui est renseigné.
String spokenSetValue(WorkoutSetEntry entry) {
  final kind = entry.kind != SetKind.normal ? ' · ${entry.kind.label}' : '';
  if (entry.durationSeconds != null) {
    final duree = formatDuration(entry.durationSeconds!);
    final distance = entry.distanceMeters;
    final parcouru = distance == null
        ? ''
        : ' · ${formatThousands(distance)} m';
    return '${duree.value} ${duree.unit}$parcouru$kind';
  }
  final weight = entry.weightKg == null ? '—' : formatDecimal(entry.weightKg!);
  final reps = entry.reps == null ? '—' : formatThousands(entry.reps!);
  return '$weight kg × $reps$kind';
}

/// « Prévu 8 × 60 kg » — la cible AFFICHÉE au moment de la validation.
///
/// Elle est stockée sur la série elle-même : l'écart prévu/réalisé reste
/// consultable des mois plus tard, indépendamment du modèle d'origine.
String? plannedLabel(WorkoutSetEntry set) {
  final reps = set.plannedReps;
  final weight = set.plannedWeightKg;
  if (reps == null && weight == null) {
    return null;
  }
  final parts = [
    if (reps != null) formatThousands(reps),
    if (weight != null) '${formatDecimal(weight)} kg',
  ];
  return 'Prévu ${parts.join(' × ')}';
}
