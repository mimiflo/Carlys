/// Lignes JSON de `/api/v1/community` → entités du domaine.
///
/// Du transport, rien d'autre : la confidentialité est décidée par le
/// serveur, qui envoie `null` là où l'ami garde sa progression privée.
library;

import '../../domain/entities/community.dart';
import '../../domain/entities/community_moderation.dart';

Encouragement encouragementFromJson(Map<String, dynamic> row) {
  return Encouragement(
    id: row['id'] as String,
    fromUserId: row['fromUserId'] as String,
    fromName: row['fromDisplayName'] as String,
    message: row['message'] as String,
    sentAt: DateTime.parse(row['sentAt'] as String),
  );
}

CommunityFriend friendFromJson(Map<String, dynamic> row) {
  return CommunityFriend(
    id: row['userId'] as String,
    displayName: row['displayName'] as String,
    sharesProgress: row['sharesProgress'] as bool,
    streakDays: (row['streakDays'] as num?)?.toInt(),
    weeklySessions: (row['weeklySessions'] as num?)?.toInt(),
  );
}

FriendRequest friendRequestFromJson(Map<String, dynamic> row) {
  return FriendRequest(
    id: row['id'] as String,
    fromDisplayName: row['fromDisplayName'] as String,
    createdAt: DateTime.parse(row['createdAt'] as String),
  );
}

CommunityChallenge challengeFromJson(Map<String, dynamic> row) {
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

BlockedUser blockedUserFromJson(Map<String, dynamic> row) {
  return BlockedUser(
    userId: row['userId'] as String,
    displayName: row['displayName'] as String,
    blockedAt: DateTime.parse(row['blockedAt'] as String),
  );
}
