import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/domain/repositories/workout_repository.dart';
import '../entities/session_plan.dart';
import '../repositories/workout_template_repository.dart';

/// Résultat de la validation d'une série : ce qui a été enregistré, et l'item
/// de plan que cela a honoré (`null` = série hors programme).
class RecordedSet {
  const RecordedSet({required this.setId, this.fulfilled});

  final String setId;
  final SessionPlanItem? fulfilled;
}

/// **Valider une série pendant une séance issue d'un modèle.**
///
/// Point d'entrée unique de l'écran de séance active : il applique la règle
/// d'appariement une fois pour toutes, au lieu de la laisser se disperser dans
/// les widgets.
///
/// Déroulé :
///  1. chercher l'item de plan que cette série honore (premier item de
///     l'exercice ni fait ni sauté) ;
///  2. enregistrer la série avec ses valeurs **réelles**, en y recopiant la
///     cible affichée (`plannedReps` / `plannedWeightKg`) — c'est ce qui
///     permettra de relire « prévu 8 × 60 kg, fait 7 × 60 kg » des mois plus
///     tard, même modèle supprimé ;
///  3. marquer l'item honoré.
///
/// **Aucune déviation n'est une erreur** : faire 7 répétitions au lieu de 8
/// honore quand même l'item ; une série supplémentaire est enregistrée
/// normalement, sans item ni cibles, donc sans faire dépasser l'avancement.
/// Une séance libre (sans plan) traverse ce cas d'usage sans rien changer au
/// comportement existant.
class RecordPlannedSet {
  const RecordPlannedSet({required this._workouts, required this._templates});

  final WorkoutRepository _workouts;
  final WorkoutTemplateRepository _templates;

  Future<RecordedSet> call(AddSetInput input) async {
    final planItem = await _templates.nextPlanItemFor(
      sessionId: input.sessionId,
      exerciseName: input.exerciseName,
      exerciseId: input.exerciseId,
    );

    // Série libre : une écriture. Série qui honore une prévision : UNE
    // écriture elle aussi, côté modèles, qui enchaîne la série et le pointage
    // de l'item dans la même transaction. Les deux gestes étaient auparavant
    // deux transactions distinctes, et une application tuée entre elles
    // laissait la série enregistrée avec la case du plan vide.
    if (planItem == null) {
      final setId = await _workouts.addSet(input);
      return RecordedSet(setId: setId, fulfilled: null);
    }

    final setId = await _templates.recordSetFulfillingPlan(
      input: input.copyWith(
        plannedReps: planItem.targetReps,
        plannedWeightKg: planItem.targetWeightKg,
        planItemId: planItem.id,
      ),
      planItemId: planItem.id,
    );
    return RecordedSet(setId: setId, fulfilled: planItem);
  }
}
