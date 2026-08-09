import '../entities/coach.dart';

/// Contrat du domaine coach.
///
/// **Seul domaine de l'application qui n'écrit pas hors ligne**, et c'est
/// délibéré : une question posée sans réseau recevrait sa réponse des heures
/// plus tard, ce qui n'est plus une conversation. Les identifiants, eux,
/// restent générés sur l'appareil — ouvrir un fil et envoyer un message sont
/// donc rejouables sans créer de doublon.
abstract interface class CoachRepository {
  /// Fils de l'utilisateur, du plus récemment actif au plus ancien.
  Future<List<CoachConversationSummary>> conversations();

  /// Ouvre un fil sur un identifiant fourni par l'appareil (rejouable).
  Future<CoachConversationSummary> createConversation(String id);

  /// Un fil avec ses messages et les séances proposées.
  Future<CoachConversation> conversation(String id);

  /// Envoie un message et rend la réplique du coach.
  ///
  /// [messageId] vient de l'appareil : renvoyer la même requête ne crée aucun
  /// doublon.
  Future<CoachReply> sendMessage({
    required String conversationId,
    required String messageId,
    required String content,
  });

  /// Signale qu'une proposition a été lancée. N'écrit **aucune** séance : la
  /// séance naît par le chemin de séance existant, déjà idempotent.
  Future<void> markProposalAccepted({
    required String proposalId,
    required String sessionId,
  });
}
