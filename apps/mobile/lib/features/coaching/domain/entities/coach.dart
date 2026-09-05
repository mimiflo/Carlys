/// Entités du domaine coach (immuables, écrites à la main).
library;

import '../../../workout_session/domain/entities/workout.dart';

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

/// Série d'une séance proposée, **telle que le serveur la renvoie** : à plat,
/// une ligne par série, exactement comme le plan d'une séance.
///
/// C'est cette forme-là — et non le regroupement d'affichage — qui permet de
/// lancer la séance : accepter une proposition est alors une copie, pas une
/// traduction.
class CoachProposalSet {
  const CoachProposalSet({
    required this.id,
    required this.exercisePosition,
    required this.exerciseId,
    required this.exerciseName,
    required this.setPosition,
    required this.kind,
    this.targetReps,
    this.targetWeightKg,
    this.restSeconds,
  });

  final String id;
  final int exercisePosition;

  /// Toujours un exercice RÉEL du catalogue : le serveur rejette la
  /// proposition entière si un identifiant lui est inconnu.
  final String exerciseId;
  final String exerciseName;
  final int setPosition;
  final SetKind kind;
  final int? targetReps;
  final double? targetWeightKg;
  final int? restSeconds;
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
    this.sets = const [],
    this.acceptedSessionId,
  });

  final String id;
  final String name;
  final int estimatedMinutes;

  /// Vue d'affichage, regroupée par exercice.
  final List<CoachProposedExercise> exercises;

  /// Vue exécutable, à plat — ce qui devient le plan de la séance.
  final List<CoachProposalSet> sets;

  /// Séance née de cette proposition, quand elle a déjà été lancée.
  final String? acceptedSessionId;

  bool get isAccepted => acceptedSessionId != null;
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

/// Fil de discussion complet.
class CoachConversation {
  const CoachConversation({
    required this.id,
    required this.messages,
    this.title,
  });

  final String id;

  /// Du plus ancien au plus récent : c'est l'ordre de lecture, et l'écran
  /// inverse lui-même sa liste pour ancrer la conversation en bas.
  final List<CoachMessage> messages;
  final String? title;
}

/// Résumé d'un fil, pour la liste des conversations.
class CoachConversationSummary {
  const CoachConversationSummary({
    required this.id,
    required this.messagesCount,
    required this.updatedAt,
    this.title,
  });

  final String id;
  final int messagesCount;
  final DateTime updatedAt;
  final String? title;
}

/// Réponse à un envoi : le message écrit ET la réplique du coach.
class CoachReply {
  const CoachReply({
    required this.userMessage,
    required this.assistantMessage,
    required this.remainingToday,
  });

  final CoachMessage userMessage;
  final CoachMessage assistantMessage;

  /// Messages restants pour la journée après cet échange — décidé par le
  /// serveur, jamais compté sur l'appareil.
  final int remainingToday;
}
