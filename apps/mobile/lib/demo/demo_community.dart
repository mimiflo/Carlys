/// Communauté du MODE DÉMO : des amis, des mots, des défis — en mémoire.
///
/// Même règle que les autres dépôts de démonstration : l'état vit le temps du
/// processus, rejoindre un défi, répondre à une demande, envoyer un
/// encouragement ou bloquer quelqu'un se voit immédiatement, rien ne touche
/// le réseau.
library;

import '../features/community/domain/entities/community.dart';
import '../features/community/domain/entities/community_moderation.dart';
import '../features/community/domain/friend_code.dart';
import '../features/community/domain/repositories/community_repository.dart';

class DemoCommunityRepository implements CommunityRepository {
  final List<Encouragement> _received = [
    Encouragement(
      id: 'demo-encouragement-1',
      fromUserId: 'demo-friend-sarah',
      fromName: 'Sarah',
      message: 'Belle série de 6 jours, continue comme ça ! 💪',
      sentAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Encouragement(
      id: 'demo-encouragement-2',
      fromUserId: 'demo-friend-mehdi',
      fromName: 'Mehdi',
      message: 'Ton volume de la semaine est impressionnant.',
      sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    ),
    Encouragement(
      id: 'demo-encouragement-3',
      fromUserId: 'demo-friend-lea',
      fromName: 'Léa',
      message: 'On se fait le défi du haut du corps ensemble ?',
      sentAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final List<CommunityFriend> _friends = [
    const CommunityFriend(
      id: 'demo-friend-sarah',
      displayName: 'Sarah',
      streakDays: 11,
      weeklySessions: 4,
      sharesProgress: true,
    ),
    const CommunityFriend(
      id: 'demo-friend-mehdi',
      displayName: 'Mehdi',
      streakDays: 6,
      weeklySessions: 3,
      sharesProgress: true,
    ),
    const CommunityFriend(
      id: 'demo-friend-lea',
      displayName: 'Léa',
      streakDays: 4,
      weeklySessions: 5,
      sharesProgress: true,
    ),
    // Profil privé : la progression n'a JAMAIS quitté le serveur — null,
    // pas zéro. L'écran ne montre que le nom.
    const CommunityFriend(
      id: 'demo-friend-tom',
      displayName: 'Tom',
      streakDays: null,
      weeklySessions: null,
      sharesProgress: false,
    ),
  ];

  final List<FriendRequest> _requests = [
    FriendRequest(
      id: 'demo-request-nina',
      fromDisplayName: 'Nina',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  final Map<String, CommunityChallenge> _challenges = {
    'demo-challenge-squats': CommunityChallenge(
      id: 'demo-challenge-squats',
      kind: ChallengeKind.sport,
      title: '10 000 squats à plusieurs',
      description:
          'Le groupe additionne ses répétitions de squat jusqu’à 10 000 avant la fin du mois.',
      participants: 47,
      progress: 0.62,
      joined: true,
      endsAt: DateTime.now().add(const Duration(days: 12)),
    ),
    'demo-challenge-anatomie': CommunityChallenge(
      id: 'demo-challenge-anatomie',
      kind: ChallengeKind.culture,
      title: 'Qui connaît le mieux le haut du corps ?',
      description:
          'Cinq questions d’anatomie par jour pendant une semaine. Le meilleur score gagne.',
      participants: 23,
      progress: 0.4,
      joined: false,
      endsAt: DateTime.now().add(const Duration(days: 5)),
    ),
    'demo-challenge-constance': CommunityChallenge(
      id: 'demo-challenge-constance',
      kind: ChallengeKind.sport,
      title: '21 jours de constance',
      description:
          'Une activité par jour pendant trois semaines, quelle qu’elle soit. La série collective compte.',
      participants: 128,
      progress: 0.78,
      joined: false,
      endsAt: DateTime.now().add(const Duration(days: 17)),
    ),
  };

  /// Personne au départ : la liste se remplit par le geste « Bloquer ».
  final List<BlockedUser> _blocked = [];

  bool _sharesProgress = true;
  int _nextId = 0;

  @override
  Future<List<Encouragement>> encouragements() async =>
      [..._received]..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  @override
  Future<List<CommunityFriend>> friends() async =>
      [..._friends]
        ..sort((a, b) => (b.streakDays ?? -1).compareTo(a.streakDays ?? -1));

  @override
  Future<List<FriendRequest>> receivedRequests() async => [..._requests];

  @override
  Future<void> sendFriendRequest(String email) async {
    // Réponse opaque, comme le vrai serveur : rien ne se passe de visible.
  }

  /// Codes amis du monde de démonstration — mêmes règles que le serveur
  /// (8 caractères de l'alphabet sans ambiguïté).
  static const String _myCode = 'CWDEM742';
  static const Map<String, String> _knownCodes = {
    'AC23DEF4': 'Sarah',
    'MK78WXY2': 'Mehdi',
  };

  @override
  Future<String> myFriendCode() async => _myCode;

  @override
  Future<String?> lookupFriendCode(String code) async {
    final normalized = normalizeFriendCode(code);
    return normalized == null ? null : _knownCodes[normalized];
  }

  @override
  Future<void> sendFriendRequestByCode(String code) async {
    // Opaque, comme par e-mail : la demande part, rien d'autre à montrer.
  }

  @override
  Future<void> respondToRequest(
    String requestId, {
    required bool accept,
  }) async {
    final index = _requests.indexWhere((request) => request.id == requestId);
    if (index < 0) {
      return;
    }
    final request = _requests.removeAt(index);
    if (accept) {
      _friends.add(
        CommunityFriend(
          id: 'demo-friend-${_nextId++}',
          displayName: request.fromDisplayName,
          streakDays: 2,
          weeklySessions: 1,
          sharesProgress: true,
        ),
      );
    }
  }

  @override
  Future<void> removeFriend(String userId) async {
    // Idempotent, comme le serveur : retirer deux fois ne se voit pas.
    _friends.removeWhere((friend) => friend.id == userId);
  }

  @override
  Future<List<CommunityChallenge>> challenges() async =>
      _challenges.values.toList()..sort((a, b) => a.endsAt.compareTo(b.endsAt));

  @override
  Future<CommunityChallenge> joinChallenge(String challengeId) =>
      _setJoined(challengeId, joined: true);

  @override
  Future<CommunityChallenge> leaveChallenge(String challengeId) =>
      _setJoined(challengeId, joined: false);

  Future<CommunityChallenge> _setJoined(
    String challengeId, {
    required bool joined,
  }) async {
    final challenge = _challenges[challengeId];
    if (challenge == null) {
      throw ArgumentError.value(challengeId, 'challengeId', 'défi inconnu');
    }
    if (challenge.joined == joined) {
      return challenge; // Idempotent, comme le serveur.
    }
    final updated = challenge.copyWith(
      joined: joined,
      participants: challenge.participants + (joined ? 1 : -1),
    );
    _challenges[challengeId] = updated;
    return updated;
  }

  @override
  Future<void> encourage(String friendId, String message) async {
    final friend = _friends.firstWhere((f) => f.id == friendId);
    // En démo, l'encouragement envoyé revient dans le fil comme un merci :
    // l'écran montre le cycle complet sans serveur.
    _received.insert(
      0,
      Encouragement(
        id: 'demo-sent-${_nextId++}',
        fromUserId: friend.id,
        fromName: friend.displayName,
        message: 'Merci pour ton message ! 🙌',
        sentAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> reportQuizAnswer({
    required String lessonId,
    required String answeredOn,
    required bool correct,
  }) async {
    // La démo n'a pas d'objectif chiffré derrière ses barres : la réponse
    // est acceptée et c'est tout — le vrai comptage est serveur.
  }

  @override
  Future<bool> sharesProgress() async => _sharesProgress;

  @override
  Future<void> setSharesProgress({required bool value}) async {
    _sharesProgress = value;
  }

  // ── Se protéger ─────────────────────────────────────────────────────────

  /// Comme le serveur : l'ami disparaît, ses mots aussi, sans un mot pour
  /// lui ; la personne rejoint la liste des blocages.
  @override
  Future<void> blockUser(String userId) async {
    final index = _friends.indexWhere((friend) => friend.id == userId);
    if (index < 0) {
      return; // Idempotent : déjà bloqué, ou inconnu de la démo.
    }
    final friend = _friends.removeAt(index);
    _received.removeWhere((word) => word.fromUserId == userId);
    _blocked.insert(
      0,
      BlockedUser(
        userId: userId,
        displayName: friend.displayName,
        blockedAt: DateTime.now(),
      ),
    );
  }

  /// Débloquer ne rétablit rien : l'amitié se redemande.
  @override
  Future<void> unblockUser(String userId) async {
    _blocked.removeWhere((blocked) => blocked.userId == userId);
  }

  @override
  Future<List<BlockedUser>> listBlocked() async => [..._blocked];

  @override
  Future<void> reportUser(String userId, CommunityReportDraft report) async {
    // Le signalement part vers l'équipe : en démo comme en vrai, rien à
    // montrer à l'écran.
  }

  @override
  Future<void> reportEncouragement(
    Encouragement encouragement,
    CommunityReportDraft report,
  ) async {
    // Même silence que pour une personne.
  }

  @override
  Future<void> deleteEncouragement(String encouragementId) async {
    _received.removeWhere((word) => word.id == encouragementId);
  }
}
