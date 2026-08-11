import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/community.dart';
import '../../domain/repositories/community_repository.dart';

/// Communauté servie par l'API (/api/v1/community).
///
/// La confidentialité est décidée CÔTÉ SERVEUR : quand un ami ne partage pas
/// sa progression, `streakDays` et `weeklySessions` arrivent `null` — ce
/// dépôt transporte, il ne décide rien.
class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Encouragement>> encouragements() {
    return _guard(() async {
      final rows = await _list('/community/feed');
      return rows
          .map(
            (row) => Encouragement(
              id: row['id'] as String,
              fromName: row['fromDisplayName'] as String,
              message: row['message'] as String,
              sentAt: DateTime.parse(row['sentAt'] as String),
            ),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<List<CommunityFriend>> friends() {
    return _guard(() async {
      final rows = await _list('/community/friends');
      final friends = rows
          .map(
            (row) => CommunityFriend(
              id: row['userId'] as String,
              displayName: row['displayName'] as String,
              sharesProgress: row['sharesProgress'] as bool,
              streakDays: (row['streakDays'] as num?)?.toInt(),
              weeklySessions: (row['weeklySessions'] as num?)?.toInt(),
            ),
          )
          .toList();
      friends.sort(
        (a, b) => (b.streakDays ?? -1).compareTo(a.streakDays ?? -1),
      );
      return friends;
    });
  }

  @override
  Future<List<FriendRequest>> receivedRequests() {
    return _guard(() async {
      final rows = await _list('/community/requests');
      return rows
          .map(
            (row) => FriendRequest(
              id: row['id'] as String,
              fromDisplayName: row['fromDisplayName'] as String,
              createdAt: DateTime.parse(row['createdAt'] as String),
            ),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<void> sendFriendRequest(String email) {
    return _guard(() async {
      await _dio.post<Map<String, dynamic>>(
        '/community/requests',
        data: {'email': email},
      );
    });
  }

  @override
  Future<void> respondToRequest(String requestId, {required bool accept}) {
    return _guard(() async {
      final action = accept ? 'accept' : 'decline';
      await _dio
          .post<Map<String, dynamic>>('/community/requests/$requestId/$action');
    });
  }

  @override
  Future<List<CommunityChallenge>> challenges() {
    return _guard(() async {
      final rows = await _list('/community/challenges');
      return rows.map(_challenge).toList(growable: false);
    });
  }

  @override
  Future<CommunityChallenge> joinChallenge(String challengeId) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/community/challenges/$challengeId/join',
      );
      return _challenge(_data(response));
    });
  }

  @override
  Future<CommunityChallenge> leaveChallenge(String challengeId) {
    return _guard(() async {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/community/challenges/$challengeId/join',
      );
      return _challenge(_data(response));
    });
  }

  @override
  Future<void> encourage(String friendId, String message) {
    return _guard(() async {
      await _dio.post<Map<String, dynamic>>(
        '/community/encouragements',
        data: {'recipientUserId': friendId, 'message': message},
      );
    });
  }

  @override
  Future<bool> sharesProgress() {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/community/profile');
      return _data(response)['sharesProgress'] as bool;
    });
  }

  @override
  Future<void> setSharesProgress({required bool value}) {
    return _guard(() async {
      await _dio.patch<Map<String, dynamic>>(
        '/community/profile',
        data: {'sharesProgress': value},
      );
    });
  }

  CommunityChallenge _challenge(Map<String, dynamic> row) {
    return CommunityChallenge(
      id: row['id'] as String,
      kind: row['kind'] == 'CULTURE'
          ? ChallengeKind.culture
          : ChallengeKind.sport,
      title: row['title'] as String,
      description: row['description'] as String,
      participants: (row['participants'] as num).toInt(),
      progress: (row['progress'] as num).toDouble(),
      joined: row['joined'] as bool,
      endsAt: DateTime.parse(row['endsAt'] as String),
    );
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    return response.data?['data'] as Map<String, dynamic>? ?? const {};
  }

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final response = await _dio.get<Map<String, dynamic>>(path);
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepositoryImpl(ref.watch(dioProvider));
});
