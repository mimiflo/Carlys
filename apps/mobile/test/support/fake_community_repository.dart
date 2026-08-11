import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/domain/repositories/community_repository.dart';

/// Dépôt communauté pilotable : listes en mémoire, pannes à la demande.
class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({
    this.failReads = false,
    List<Encouragement>? feed,
    List<CommunityFriend>? friends,
    List<FriendRequest>? requests,
    List<CommunityChallenge>? challenges,
    this.shares = true,
  })  : _feed = feed ?? [],
        _friends = friends ?? [],
        _requests = requests ?? [],
        _challenges = challenges ?? [];

  /// À activer pour simuler un serveur injoignable.
  bool failReads;

  final List<Encouragement> _feed;
  final List<CommunityFriend> _friends;
  final List<FriendRequest> _requests;
  final List<CommunityChallenge> _challenges;
  bool shares;

  /// Adresses reçues par [sendFriendRequest], dans l'ordre.
  final List<String> sentRequests = [];

  void _guard() {
    if (failReads) {
      throw StateError('communauté injoignable (voulu par le test)');
    }
  }

  @override
  Future<List<Encouragement>> encouragements() async {
    _guard();
    return List.unmodifiable(_feed);
  }

  @override
  Future<List<CommunityFriend>> friends() async {
    _guard();
    return List.unmodifiable(_friends);
  }

  @override
  Future<List<FriendRequest>> receivedRequests() async {
    _guard();
    return List.unmodifiable(_requests);
  }

  @override
  Future<void> sendFriendRequest(String email) async {
    _guard();
    sentRequests.add(email);
  }

  @override
  Future<void> respondToRequest(
    String requestId, {
    required bool accept,
  }) async {
    _guard();
    final index = _requests.indexWhere((request) => request.id == requestId);
    if (index < 0) {
      return;
    }
    final request = _requests.removeAt(index);
    if (accept) {
      _friends.add(
        CommunityFriend(
          id: 'ami-${request.id}',
          displayName: request.fromDisplayName,
          streakDays: 1,
          weeklySessions: 1,
          sharesProgress: true,
        ),
      );
    }
  }

  @override
  Future<List<CommunityChallenge>> challenges() async {
    _guard();
    return List.unmodifiable(_challenges);
  }

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
    _guard();
    final index = _challenges.indexWhere((c) => c.id == challengeId);
    if (index < 0) {
      throw ArgumentError.value(challengeId, 'challengeId', 'défi inconnu');
    }
    final challenge = _challenges[index];
    if (challenge.joined == joined) {
      return challenge;
    }
    final updated = challenge.copyWith(
      joined: joined,
      participants: challenge.participants + (joined ? 1 : -1),
    );
    _challenges[index] = updated;
    return updated;
  }

  @override
  Future<void> encourage(String friendId, String message) async {
    _guard();
  }

  @override
  Future<bool> sharesProgress() async {
    _guard();
    return shares;
  }

  @override
  Future<void> setSharesProgress({required bool value}) async {
    _guard();
    shares = value;
  }
}
