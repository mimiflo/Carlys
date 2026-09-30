import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/domain/repositories/coach_repository.dart';

/// Coach de test : rend ce qu'on lui dit de rendre, ou l'erreur qu'on lui
/// confie. Aucun réseau, aucun modèle.
class FakeCoachRepository implements CoachRepository {
  FakeCoachRepository({
    this.threads = const [],
    this.messages = const [],
    this.listError,
    this.sendError,
    this.reply,
    this.cached,
  });

  final List<CoachConversationSummary> threads;
  final List<CoachMessage> messages;

  /// Erreur levée à l'ouverture (droit absent, hors ligne, coach coupé).
  ///
  /// MUTABLE, comme [sendError] : le réseau qui revient se rejoue en la
  /// remettant à `null`.
  AppException? listError;

  /// Le fil gardé sur l'appareil pour la relecture hors ligne.
  final CoachConversation? cached;

  /// Erreur levée à l'envoi (plafond atteint, réseau perdu en route).
  ///
  /// MUTABLE à dessein : une coupure passagère se rejoue en la remettant à
  /// `null` entre deux envois, ce qui est exactement le scénario où
  /// l'identifiant de message doit être réutilisé.
  AppException? sendError;

  final CoachReply? reply;

  /// Morceaux rendus au fil de l'écriture, avant la réplique.
  List<String> streamed = const [];

  final List<String> sent = [];

  /// Les identifiants reçus, dans l'ordre : c'est la clé d'idempotence du
  /// serveur, et deux tentatives d'une même question doivent la partager.
  final List<String> sentIds = [];
  final List<String> createdConversations = [];
  final List<({String proposalId, String sessionId})> accepted = [];

  @override
  Future<List<CoachConversationSummary>> conversations() async {
    final error = listError;
    if (error != null) throw error;
    return threads;
  }

  @override
  Future<CoachConversationSummary> createConversation(String id) async {
    createdConversations.add(id);
    return CoachConversationSummary(
      id: id,
      messagesCount: 0,
      updatedAt: DateTime.utc(2026, 8, 9),
    );
  }

  @override
  Future<CoachConversation> conversation(String id) async {
    final error = listError;
    if (error != null) throw error;
    return CoachConversation(id: id, messages: messages);
  }

  @override
  Future<CoachConversation?> offlineConversation() async => cached;

  @override
  Future<CoachReply> sendMessage({
    required String conversationId,
    required String messageId,
    required String content,
    void Function(String text)? onText,
  }) async {
    sent.add(content);
    sentIds.add(messageId);
    final error = sendError;
    if (error != null) throw error;
    for (final part in streamed) {
      onText?.call(part);
    }

    return reply ??
        CoachReply(
          userMessage: CoachMessage(
            id: messageId,
            role: CoachRole.user,
            content: content,
          ),
          assistantMessage: const CoachMessage(
            id: 'answer',
            role: CoachRole.assistant,
            content: 'Bien reçu.',
          ),
          remainingToday: 29,
        );
  }

  @override
  Future<void> markProposalAccepted({
    required String proposalId,
    required String sessionId,
  }) async {
    accepted.add((proposalId: proposalId, sessionId: sessionId));
  }
}
