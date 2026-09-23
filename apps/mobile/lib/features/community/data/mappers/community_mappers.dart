/// Lignes JSON de `/api/v1/community` → entités du domaine.
///
/// Du transport, rien d'autre : la confidentialité est décidée par le
/// serveur, qui envoie `null` là où l'ami garde sa progression privée.
library;

import '../../domain/entities/community.dart';
import '../../domain/entities/community_moderation.dart';
import '../../domain/entities/friend_challenge.dart';
import '../../domain/entities/league.dart';

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
    // Lus DÉFENSIVEMENT : un serveur déployé avant ce client ne les sert
    // pas, et un défi sans légende vaut mieux qu'un écran vide.
    target: (row['target'] as num?)?.toInt() ?? 0,
    totalContribution: (row['totalContribution'] as num?)?.toInt() ?? 0,
    unit: row['unit'] as String? ?? '',
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

FriendChallengeMember friendChallengeMemberFromJson(Map<String, dynamic> row) {
  return FriendChallengeMember(
    userId: row['userId'] as String,
    displayName: row['displayName'] as String,
    status: FriendChallengeMemberStatus.fromApi(row['status'] as String?),
    contribution: (row['contribution'] as num?)?.toInt() ?? 0,
    rank: (row['rank'] as num?)?.toInt(),
    isMe: row['isMe'] as bool? ?? false,
    isCreator: row['isCreator'] as bool? ?? false,
  );
}

FriendChallenge friendChallengeFromJson(Map<String, dynamic> row) {
  return FriendChallenge(
    id: row['id'] as String,
    title: row['title'] as String,
    metric: ChallengeMetric.fromApi(row['metric'] as String?),
    unit: row['unit'] as String? ?? '',
    target: (row['target'] as num?)?.toInt(),
    status: FriendChallengeStatus.fromApi(row['status'] as String?),
    myStatus: FriendChallengeMemberStatus.fromApi(row['myStatus'] as String?),
    startsAt: DateTime.parse(row['startsAt'] as String),
    endsAt: DateTime.parse(row['endsAt'] as String),
    creatorDisplayName: row['creatorDisplayName'] as String? ?? 'Membre Carlys',
    members: (row['members'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(friendChallengeMemberFromJson)
        .toList(growable: false),
    // Lus avec tolérance : un serveur plus ancien ne les envoie pas, et le
    // défi reste lisible sans eux.
    message: _blankToNull(row['message']),
    createdAt: DateTime.tryParse(row['createdAt'] as String? ?? ''),
    durationDays: (row['durationDays'] as num?)?.toInt(),
  );
}

String? _blankToNull(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

LeagueStanding leagueStandingFromJson(Map<String, dynamic> row) {
  return LeagueStanding(
    userId: row['userId'] as String,
    displayName: row['displayName'] as String,
    score: (row['score'] as num?)?.toInt() ?? 0,
    rank: (row['rank'] as num?)?.toInt() ?? 0,
    isMe: row['isMe'] as bool? ?? false,
  );
}

League leagueFromJson(Map<String, dynamic> row) {
  final result = row['lastResult'] as Map<String, dynamic>?;
  return League(
    joined: row['joined'] as bool? ?? false,
    periodKey: row['periodKey'] as String? ?? '',
    endsAt: DateTime.parse(row['endsAt'] as String),
    division: LeagueDivision.fromApi(row['division'] as String?),
    score: (row['score'] as num?)?.toInt() ?? 0,
    standings: (row['standings'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(leagueStandingFromJson)
        .toList(growable: false),
    lastResult: result == null
        ? null
        : LeagueResult(
            periodKey: result['periodKey'] as String? ?? '',
            rank: (result['rank'] as num?)?.toInt() ?? 0,
            from: LeagueDivision.fromApi(result['from'] as String?),
            to: LeagueDivision.fromApi(result['to'] as String?),
          ),
    promotion: leaguePromotionFromJson(row['promotion']),
  );
}

/// La zone de montée, lue TOLÉRANTE : un serveur déployé avant ce client ne
/// sert pas le bloc, et un bloc mal typé ne doit pas coûter l'écran. Dans
/// les deux cas, `null` — la ligue se lit alors sans zone, comme avant —
/// plutôt qu'une exception. Tout ou rien : un bloc à moitié lu inventerait
/// des zéros, et un `inZone` faux par défaut serait une information fausse.
LeaguePromotion? leaguePromotionFromJson(Object? raw) {
  if (raw case {
    'promotedCount': final int promotedCount,
    'minPlayers': final int minPlayers,
    'activePlayers': final int activePlayers,
    'topDivision': final bool topDivision,
    'inZone': final bool inZone,
    'zoneScore': final int? zoneScore,
    'pointsToZone': final int pointsToZone,
  }) {
    return LeaguePromotion(
      promotedCount: promotedCount,
      minPlayers: minPlayers,
      activePlayers: activePlayers,
      topDivision: topDivision,
      inZone: inZone,
      zoneScore: zoneScore,
      pointsToZone: pointsToZone,
    );
  }
  return null;
}
