/// Entités du domaine coach (immuables, écrites à la main).
library;

enum CoachRole {
  user('USER'),
  assistant('ASSISTANT');

  const CoachRole(this.apiValue);

  final String apiValue;

  static CoachRole fromApi(String value) => CoachRole.values.firstWhere(
        (role) => role.apiValue == value,
        orElse: () => CoachRole.assistant,
      );
}

/// Exercice d'une séance proposée, **regroupé pour l'affichage**.
///
/// L'API renvoie des séries à plat — une ligne par série, comme
/// `WorkoutSessionPlanItem` — parce que c'est cette forme-là que l'application
/// sait lancer. Le regroupement par exercice appartient à la couche data ; un
/// widget qui le referait à chaque image le referait pour rien.
class CoachProposedExercise {
  const CoachProposedExercise({
    required this.name,
    required this.setCount,
    required this.detail,
  });

  final String name;
  final int setCount;

  /// Résumé des cibles, déjà formaté (« 8 reps · 60 kg »).
  final String detail;
}

/// Séance proposée par le coach. Tant qu'elle n'est pas acceptée, ce n'est
/// qu'un document : elle ne compte ni dans l'historique, ni dans les stats,
/// ni dans les records.
class CoachSessionProposal {
  const CoachSessionProposal({
    required this.id,
    required this.name,
    required this.estimatedMinutes,
    required this.exercises,
  });

  final String id;
  final String name;
  final int estimatedMinutes;
  final List<CoachProposedExercise> exercises;
}

class CoachMessage {
  const CoachMessage({
    required this.id,
    required this.role,
    required this.content,
    this.proposal,
  });

  final String id;
  final CoachRole role;
  final String content;

  /// Proposition rattachée au message, quand le coach en a formulé une.
  final CoachSessionProposal? proposal;
}
