/// Traduction du **plan de séance** en consigne d'écran.
///
/// L'écran de séance active n'a pas à connaître les modèles : il reçoit des
/// valeurs déjà formulées (un sur-titre, une cible, des compteurs). Toute la
/// lecture du plan se fait ici, dans une **fonction pure** — donc testable
/// sans base, sans réseau et sans widget.
library;

import '../../../../core/utilities/formatting.dart';
import '../../domain/entities/session_plan.dart';

/// Ce que le programme dit, à l'instant présent, à l'écran de séance.
class SessionGuidance {
  const SessionGuidance({
    required this.templateName,
    required this.doneCount,
    required this.totalCount,
    required this.upcomingInSession,
    required this.upcomingInExercise,
    this.exerciseName,
    this.exerciseId,
    this.exercisePosition,
    this.planItemId,
    this.overline,
    this.targetReps,
    this.targetWeightKg,
    this.targetDurationSeconds,
    this.restSeconds,
  });

  /// Nom du modèle lancé — pastille de l'en-tête.
  final String templateName;

  /// Séries prévues honorées et total prévu : « 6 séries sur 12 prévues ».
  final int doneCount;
  final int totalCount;

  /// Séries prévues restantes **après** celle en cours de saisie — segments
  /// « à venir » de la barre de progression.
  final int upcomingInSession;

  /// Idem, limité à l'exercice affiché.
  final int upcomingInExercise;

  /// Exercice que le programme propose ensuite. `null` quand le programme est
  /// terminé : la séance continue alors librement.
  final String? exerciseName;
  final String? exerciseId;
  final int? exercisePosition;

  /// Série prévue que la prochaine validation honorerait, et sa cible.
  /// `null` pour une série supplémentaire ou un exercice hors programme :
  /// c'est une **déviation normale**, pas une erreur.
  final String? planItemId;

  /// « Série 2 sur 4 · Développé couché ».
  final String? overline;

  final int? targetReps;
  final double? targetWeightKg;

  /// Cible chronométrée du programme : elle ouvre la carte de saisie sur le
  /// chronomètre plutôt que sur les répétitions, sans quoi un gainage prescrit
  /// « 45 s » se saisirait en charge et en reps.
  final int? targetDurationSeconds;

  /// Repos prescrit après cette série ; `null` laisse la logique habituelle.
  final int? restSeconds;

  /// Constat de fin de séance, sans jugement : « 9 séries sur 12 prévues ».
  String get summary =>
      '${formatThousands(doneCount)} série'
      '${doneCount > 1 ? 's' : ''} sur ${formatThousands(totalCount)} prévue'
      '${totalCount > 1 ? 's' : ''}';
}

/// Consigne du programme pour l'exercice affiché.
///
/// [pickedExerciseName] est l'exercice **choisi à la main** : ce choix reste
/// prioritaire sur l'ordre du programme (D2 — faire les exercices dans un
/// autre ordre est autorisé). Sans choix manuel, on suit le programme.
SessionGuidance guidanceFor(
  SessionPlan plan, {
  String? pickedExerciseName,
  String? pickedExerciseId,
}) {
  final current = plan.current;
  final focusName = pickedExerciseName ?? current?.exerciseName;
  final focusId = pickedExerciseName == null
      ? current?.exerciseId
      : pickedExerciseId;

  final item = focusName == null
      ? null
      : plan.nextPendingFor(exerciseName: focusName, exerciseId: focusId);

  if (item == null) {
    // Exercice choisi hors programme, ou programme terminé : plus de cible ni
    // d'exercice proposé — et surtout **aucune position d'exercice**, pour que
    // « Passer cet exercice » ne puisse jamais sauter un autre exercice que
    // celui qu'on est en train de faire. La séance garde sa provenance et son
    // décompte : aucune série en trop ne fait bouger le dénominateur.
    return SessionGuidance(
      templateName: plan.templateName,
      doneCount: plan.doneCount,
      totalCount: plan.totalCount,
      upcomingInSession: plan.remainingCount,
      upcomingInExercise: 0,
    );
  }

  final ofExercise = plan.itemsOfExercise(item.exercisePosition);
  final pending = ofExercise.where((it) => it.isPending).length;

  return SessionGuidance(
    templateName: plan.templateName,
    doneCount: plan.doneCount,
    totalCount: plan.totalCount,
    // La série en cours de saisie occupe déjà son propre segment : on ne la
    // compte pas deux fois dans les segments « à venir ».
    upcomingInSession: plan.remainingCount - 1,
    upcomingInExercise: pending > 0 ? pending - 1 : 0,
    exerciseName: item.exerciseName,
    exerciseId: item.exerciseId,
    exercisePosition: item.exercisePosition,
    planItemId: item.id,
    // « Série 2 sur 4 » : le rang est celui de l'ITEM qu'on s'apprête à
    // faire (sa position dans le plan), le total celui prévu par le modèle
    // pour cet exercice. Compter `done + 1` ré-annonçait la série qu'on
    // venait de PASSER : une série sautée avance l'item sans compter
    // dans `done`.
    overline:
        'Série ${formatThousands(item.setPosition + 1)} sur '
        '${formatThousands(ofExercise.length)} · ${item.exerciseName}',
    targetReps: item.targetReps,
    targetDurationSeconds: item.targetDurationSeconds,
    targetWeightKg: item.targetWeightKg,
    restSeconds: item.restSeconds,
  );
}
