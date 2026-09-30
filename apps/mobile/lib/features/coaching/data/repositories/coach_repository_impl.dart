import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/coach.dart';
import '../../domain/repositories/coach_repository.dart';
import '../coach_thread_cache.dart';
import '../dto/coach_dtos.dart';
import 'coach_reply_stream.dart';

/// Délai de réception de l'envoi d'un message : le serveur laisse 50 s au
/// fournisseur d'IA pour tout le tour (`COACH_TURN_DEADLINE_MS`), plus que
/// les 20 s du client partagé. En flux, c'est surtout l'attente du PREMIER
/// mot (le coach consulte tes séances, réfléchit) qu'il couvre. Sans ce délai
/// propre, une réponse lente s'afficherait « hors ligne » alors qu'elle
/// arrive.
const coachReplyTimeout = Duration(seconds: 65);

/// Dépôt coach — **direct sur l'API**, sans base locale ni file de
/// synchronisation. Seule une copie du dernier fil reste sur l'appareil, pour
/// le RELIRE hors ligne ([CoachThreadCache]).
///
/// C'est la seule exception de l'application à la règle offline-first, et elle
/// est assumée : rejouer plus tard une question posée hors ligne rendrait une
/// réponse sans rapport avec le moment où elle a été posée. Le composeur se
/// désactive alors au lieu de faire semblant.
class CoachRepositoryImpl implements CoachRepository {
  const CoachRepositoryImpl(this._dio, this._cache);

  final Dio _dio;
  final CoachThreadCache _cache;

  @override
  Future<List<CoachConversationSummary>> conversations() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/coach/conversations',
      );
      return (response.data?['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(coachSummaryFromJson)
          .toList();
    });
  }

  @override
  Future<CoachConversationSummary> createConversation(String id) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/coach/conversations',
        data: {'id': id},
      );
      return coachSummaryFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<CoachConversation> conversation(String id) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/coach/conversations/$id',
      );
      final json = response.data?['data'] as Map<String, dynamic>? ?? const {};
      final conversation = coachConversationFromJson(json);
      await _cache.save(json);
      return conversation;
    });
  }

  @override
  Future<CoachConversation?> offlineConversation() => _cache.read();

  @override
  Future<CoachReply> sendMessage({
    required String conversationId,
    required String messageId,
    required String content,
    void Function(String text)? onText,
  }) {
    return _guard(() async {
      final response = await _dio.post<ResponseBody>(
        '/coach/conversations/$conversationId/messages/stream',
        // L'identifiant vient de l'appareil : un renvoi ne crée pas un
        // second message, et ne consomme pas un second message de quota.
        data: {'id': messageId, 'content': content},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: coachReplyTimeout,
        ),
      );
      return readCoachReplyStream(
        response,
        onText,
        onDone: (json) => _cache.append(conversationId, [
          json['userMessage'] as Map<String, dynamic>,
          json['assistantMessage'] as Map<String, dynamic>,
        ]),
      );
    });
  }

  @override
  Future<void> markProposalAccepted({
    required String proposalId,
    required String sessionId,
  }) async {
    // La copie d'abord : c'est hors ligne, quand la note au serveur échoue,
    // qu'elle doit déjà savoir que la séance existe.
    await _cache.markAccepted(proposalId, sessionId);
    return _guard(
      () => _dio.post<void>(
        '/coach/proposals/$proposalId/accepted',
        data: {'sessionId': sessionId},
      ),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(await withReadableBody(exception));
    }
  }
}

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return CoachRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(coachThreadCacheProvider),
  );
});
