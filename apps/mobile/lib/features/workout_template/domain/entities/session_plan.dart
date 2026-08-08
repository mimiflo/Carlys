/// Plan de la séance en cours : la copie du modèle matérialisée au lancement.
///
/// **Copie, pas lien vivant** (D1) : modifier le modèle pendant la séance ne
/// change rien à la séance en cours, et l'historique reste vrai.
///
/// Le plan est **aplati** — une entrée par série prévue — parce que c'est la
/// forme dont l'écran de séance a besoin : « série 2 sur 4, 8 reps à 60 kg ».
library;

import '../../../workout_session/domain/entities/workout.dart';

/// Une série prévue de la séance en cours, et son sort.
class SessionPlanItem {
  const SessionPlanItem({
    required this.id,
    required this.sessionId,
    required this.exercisePosition,
    required this.exerciseName,
    required this.setPosition,
    this.exerciseId,
    this.kind = SetKind.normal,
    this.targetReps,
    this.targetWeightKg,
    this.restSeconds,
    this.doneSetId,
    this.skipped = false,
  });

  final String id;
  final String sessionId;

  /// Rang de l'exercice dans le programme, à partir de 0.
  final int exercisePosition;
  final String? exerciseId;
  final String exerciseName;

  /// Rang de la série DANS l'exercice, à partir de 0.
  final int setPosition;
  final SetKind kind;
  final int? targetReps;
  final double? targetWeightKg;
  final int? restSeconds;

  /// Série réalisée qui a honoré cet item, sinon `null`.
  final String? doneSetId;

  /// Série volontairement passée. Rien n'est envoyé au serveur : une série non
  /// faite n'est pas un fait.
  final bool skipped;

  bool get isDone => doneSetId != null;

  /// Ni faite ni sautée : c'est parmi ces items que l'appariement choisit.
  bool get isPending => !isDone && !skipped;
}

/// Le plan complet d'une séance, avec son avancement.
class SessionPlan {
  const SessionPlan({
    required this.sessionId,
    required this.templateName,
    required this.items,
  });

  final String sessionId;

  /// Nom du modèle au lancement — affiché en pastille dans l'en-tête.
  final String templateName;

  /// Items ordonnés par (exercicePosition, setPosition).
  final List<SessionPlanItem> items;

  /// Séries prévues déjà honorées. Ne dépasse jamais [totalCount] : une série
  /// en trop n'honore aucun item (règle d'appariement).
  int get doneCount => items.where((item) => item.isDone).length;

  int get totalCount => items.length;

  /// Séries encore à faire (ni honorées ni sautées).
  int get remainingCount => items.where((item) => item.isPending).length;

  /// Prochaine série prévue du programme, `null` quand tout est fait ou sauté.
  SessionPlanItem? get current {
    for (final item in items) {
      if (item.isPending) {
        return item;
      }
    }
    return null;
  }

  /// Items d'un exercice donné, dans l'ordre.
  List<SessionPlanItem> itemsOfExercise(int exercisePosition) => items
      .where((item) => item.exercisePosition == exercisePosition)
      .toList(growable: false);

  /// **Règle d'appariement**, énoncée ici une fois pour toutes : le premier
  /// item de l'exercice concerné qui n'est ni fait ni sauté. `null` quand il
  /// n'y en a aucun — série supplémentaire, ou exercice hors programme.
  ///
  /// Deux exercices du catalogue se comparent par identifiant ; un exercice
  /// libre (hors catalogue) se compare par nom, insensible à la casse.
  SessionPlanItem? nextPendingFor({
    required String exerciseName,
    String? exerciseId,
  }) {
    final name = exerciseName.trim().toLowerCase();
    for (final item in items) {
      if (!item.isPending) {
        continue;
      }
      final matches = item.exerciseId != null && exerciseId != null
          ? item.exerciseId == exerciseId
          : item.exerciseName.toLowerCase() == name;
      if (matches) {
        return item;
      }
    }
    return null;
  }

  /// Avancement de l'exercice courant : (série honorée, total prévu) pour
  /// afficher « Série 2 sur 4 ». `null` hors programme.
  (int, int)? progressOfExercise(int exercisePosition) {
    final ofExercise = itemsOfExercise(exercisePosition);
    if (ofExercise.isEmpty) {
      return null;
    }
    final done = ofExercise.where((item) => item.isDone).length;
    return (done, ofExercise.length);
  }
}
