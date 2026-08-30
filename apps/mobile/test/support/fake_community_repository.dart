import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/domain/repositories/community_repository.dart';

/// Dépôt communauté pilotable : listes en mémoire, pannes à la demande.
class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({
    this.failReads = false,
    this.offline = false,
    List<Encouragement>? feed,
    List<CommunityFriend>? friends,
    List<FriendRequest>? requests,
    List<CommunityChallenge>? challenges,
    this.shares = true,
  })  : _feed = feed ?? [],
        _friends = friends ?? [],
        _requests = requests ?? [],
        _challenges = challenges ?? [];

  /// À activer pour simuler une PANNE serveur (erreur générique).
  bool failReads;

  /// À activer pour simuler l'ABSENCE de réseau (état hors connexion).
  bool offline;

  final List<Encouragement> _feed;
  final List<CommunityFriend> _friends;
  final List<FriendRequest> _requests;
  final List<CommunityChallenge> _challenges;
  bool shares;

  /// Adresses reçues par [sendFriendRequest], dans l'ordre.
  final List<String> sentRequests = [];

  /// Codes reçus par [sendFriendRequestByCode], dans l'ordre.
  final List<String> sentCodeRequests = [];

  /// Ce que [lookupFriendCode] répond — nom du porteur, ou `null`.
  String? lookupAnswer = 'Sarah';

  void _guard() {
    if (offline) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
    if (failReads) {
      throw StateError('communauté injoignable (voulu par le test)');
    }
  }

  @override
  Future<String> myFriendCode() async {
    _guard();
    return 'AC23DEF4';
  }

  @override
  Future<String?> lookupFriendCode(String code) async {
    _guard();
    return lookupAnswer;
  }

  @override
  Future<void> sendFriendRequestByCode(String code) async {
    _guard();
    sentCodeRequests.add(code);
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

  /// Réponses de quiz reçues, dans l'ordre : (leçon, jour, juste ?).
  final List<(String, String, bool)> quizReports = [];

  @override
  Future<void> reportQuizAnswer({
    required String lessonId,
    required String answeredOn,
    required bool correct,
  }) async {
    _guard();
    quizReports.add((lessonId, answeredOn, correct));
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
