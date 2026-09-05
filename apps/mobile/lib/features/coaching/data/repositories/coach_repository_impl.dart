import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/coach.dart';
import '../../domain/repositories/coach_repository.dart';
import '../dto/coach_dtos.dart';

/// Dépôt coach — **direct sur l'API**, sans base locale ni file de
/// synchronisation.
///
/// C'est la seule exception de l'application à la règle offline-first, et elle
/// est assumée : rejouer plus tard une question posée hors ligne rendrait une
/// réponse sans rapport avec le moment où elle a été posée. Le composeur se
/// désactive alors au lieu de faire semblant.
class CoachRepositoryImpl implements CoachRepository {
  const CoachRepositoryImpl(this._dio);

  final Dio _dio;

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
      return coachConversationFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<CoachReply> sendMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/coach/conversations/$conversationId/messages',
        // L'identifiant vient de l'appareil : un renvoi ne crée pas un
        // second message, et ne consomme pas un second message de quota.
        data: {'id': messageId, 'content': content},
      );
      return coachReplyFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<void> markProposalAccepted({
    required String proposalId,
    required String sessionId,
  }) {
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
      throw mapDioException(exception);
    }
  }
}

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return CoachRepositoryImpl(ref.watch(dioProvider));
});
