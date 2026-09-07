/// Communauté du MODE DÉMO : le COMPORTEMENT du dépôt, en mémoire.
///
/// Même règle que les autres dépôts de démonstration : l'état vit le temps du
/// processus, rejoindre un défi, répondre à une demande, envoyer un
/// encouragement ou bloquer quelqu'un se voit immédiatement, rien ne touche
/// le réseau.
///
/// Le monde lui-même (amis, mots, demandes, défis, codes) est dans
/// `demo_community_seed.dart` : ce fichier ne décrit que ce qui ARRIVE quand
/// on y touche.
library;

import '../features/community/domain/entities/community.dart';
import '../features/community/domain/entities/community_moderation.dart';
import '../features/community/domain/friend_code.dart';
import '../features/community/domain/repositories/community_repository.dart';
import 'demo_community_seed.dart';

class DemoCommunityRepository implements CommunityRepository {
  final List<Encouragement> _received = demoEncouragements();
  final List<CommunityFriend> _friends = demoFriends();
  final List<FriendRequest> _requests = demoFriendRequests();
  final Map<String, CommunityChallenge> _challenges = demoChallenges();

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

  @override
  Future<String> myFriendCode() async => demoMyFriendCode;

  @override
  Future<String?> lookupFriendCode(String code) async {
    final normalized = normalizeFriendCode(code);
    return normalized == null ? null : demoKnownFriendCodes[normalized];
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
  ///
  /// Le blocage part aussi bien d'une carte d'ami que d'un mot du fil : le
  /// nom se cherche donc des DEUX côtés, l'auteur d'un mot n'étant pas
  /// forcément (ou plus) un ami.
  @override
  Future<void> blockUser(String userId) async {
    if (_blocked.any((blocked) => blocked.userId == userId)) {
      return; // Idempotent : bloquer deux fois ne se voit pas.
    }
    final name = _displayNameOf(userId);
    if (name == null) {
      return; // Personne inconnue de la démo : rien à retirer.
    }
    _friends.removeWhere((friend) => friend.id == userId);
    _received.removeWhere((word) => word.fromUserId == userId);
    _blocked.insert(
      0,
      BlockedUser(userId: userId, displayName: name, blockedAt: DateTime.now()),
    );
  }

  /// Le nom affiché d'une personne connue de la démo : un ami, ou l'auteur
  /// d'un mot du fil. `null` si la démo ne la connaît pas.
  String? _displayNameOf(String userId) {
    for (final friend in _friends) {
      if (friend.id == userId) {
        return friend.displayName;
      }
    }
    for (final word in _received) {
      if (word.fromUserId == userId) {
        return word.fromName;
      }
    }
    return null;
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
