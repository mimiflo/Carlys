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
  });

  final List<CoachConversationSummary> threads;
  final List<CoachMessage> messages;

  /// Erreur levée à l'ouverture (droit absent, hors ligne, coach coupé).
  final AppException? listError;

  /// Erreur levée à l'envoi (plafond atteint, réseau perdu en route).
  final AppException? sendError;

  final CoachReply? reply;

  final List<String> sent = [];
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
  Future<CoachReply> sendMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    sent.add(content);
    final error = sendError;
    if (error != null) throw error;

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
