import '../../../workout_session/domain/entities/workout.dart';

/// Les séries d'UN exercice d'une séance : ce que le bilan montre par carte.
class ExerciseBreakdown {
  const ExerciseBreakdown({
    required this.id,
    required this.name,
    required this.sets,
  });

  /// L'exercice du catalogue, ou le nom d'un exercice libre : stable quand
  /// une série est corrigée ou supprimée.
  final String id;
  final String name;

  /// Dans l'ordre de la séance.
  final List<WorkoutSetEntry> sets;

  /// Charge × répétitions, cumulé — comme le volume de la séance.
  double get volumeKg => sets.fold(0, (total, set) {
    final reps = set.reps;
    final weight = set.weightKg;
    return reps == null || weight == null ? total : total + reps * weight;
  });

  /// L'exercice se mesure en temps (cardio, gainage) plutôt qu'en charge.
  bool get timed => sets.any((set) => set.durationSeconds != null);

  int get totalSeconds =>
      sets.fold(0, (total, set) => total + (set.durationSeconds ?? 0));

  /// La série qui résume l'exercice replié : la plus lourde (à égalité, la
  /// plus répétée) ; la plus longue pour un exercice chronométré.
  WorkoutSetEntry get topSet {
    final byTime = timed;
    return sets.reduce((best, set) {
      if (byTime) {
        return (set.durationSeconds ?? 0) > (best.durationSeconds ?? 0)
            ? set
            : best;
      }
      final weight = set.weightKg ?? 0;
      final bestWeight = best.weightKg ?? 0;
      if (weight != bestWeight) {
        return weight > bestWeight ? set : best;
      }
      return (set.reps ?? 0) > (best.reps ?? 0) ? set : best;
    });
  }
}

/// Les séries d'une séance regroupées par exercice, dans l'ordre où chaque
/// exercice apparaît. Un exercice repris plus loin (superset, oubli) rejoint
/// SA carte au lieu d'en ouvrir une seconde. Un exercice du catalogue se
/// reconnaît à son identifiant ; un exercice libre, à son nom.
List<ExerciseBreakdown> breakdownByExercise(List<WorkoutSetEntry> sets) {
  final ordered = [...sets]..sort((a, b) => a.position.compareTo(b.position));
  final groups = <String, List<WorkoutSetEntry>>{};
  for (final set in ordered) {
    final key = set.exerciseId ?? 'libre:${set.exerciseName}';
    (groups[key] ??= []).add(set);
  }
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      ExerciseBreakdown(id: key, name: value.first.exerciseName, sets: value),
  ];
}
