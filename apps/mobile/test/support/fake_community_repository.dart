import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/domain/entities/community_moderation.dart';
import 'package:carlys_mobile/features/community/domain/entities/friend_challenge.dart';
import 'package:carlys_mobile/features/community/domain/entities/league.dart';
import 'package:carlys_mobile/features/community/domain/repositories/community_repository.dart';

/// Un signalement reçu par le dépôt factice : la personne, le message visé
/// (ou `null`), le motif et les précisions nettoyées.
typedef FakeCommunityReport = ({
  String userId,
  String? encouragementId,
  CommunityReportReason reason,
  String? details,
});

/// Dépôt communauté pilotable : listes en mémoire, pannes à la demande.
class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({
    this.failReads = false,
    this.offline = false,
    List<Encouragement>? feed,
    List<CommunityFriend>? friends,
    List<FriendRequest>? requests,
    List<CommunityChallenge>? challenges,
    List<BlockedUser>? blocked,
    this.shares = true,
  }) : _feed = feed ?? [],
       _friends = friends ?? [],
       _requests = requests ?? [],
       _challenges = challenges ?? [],
       _blocked = blocked ?? [];

  /// À activer pour simuler une PANNE serveur (erreur générique).
  bool failReads;

  /// À activer pour simuler l'ABSENCE de réseau (état hors connexion).
  bool offline;

  final List<Encouragement> _feed;
  final List<CommunityFriend> _friends;
  final List<FriendRequest> _requests;
  final List<CommunityChallenge> _challenges;
  final List<BlockedUser> _blocked;
  bool shares;

  /// Adresses reçues par [sendFriendRequest], dans l'ordre.
  final List<String> sentRequests = [];

  /// Codes reçus par [sendFriendRequestByCode], dans l'ordre.
  final List<String> sentCodeRequests = [];

  /// Ce que [lookupFriendCode] répond — nom du porteur, ou `null`.
  String? lookupAnswer = 'Sarah';

  /// Une demande d'ami qui ARRIVE entre deux lectures — ce que le serveur
  /// fait tout seul, et que seul un rafraîchissement peut faire apparaître.
  void receiveRequest(FriendRequest request) => _requests.add(request);

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

  /// L'échec que la SEULE liste d'amis oppose, les défis répondant : la
  /// feuille « Défier mes amis » ne doit pas conclure à « pas d'ami ».
  Object? friendsError;

  @override
  Future<List<CommunityFriend>> friends() async {
    _guard();
    final erreur = friendsError;
    if (erreur != null) {
      throw erreur;
    }
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

  /// Identifiants reçus par [removeFriend], dans l'ordre.
  final List<String> removedFriends = [];

  @override
  Future<void> removeFriend(String userId) async {
    _guard();
    removedFriends.add(userId);
    _friends.removeWhere((friend) => friend.id == userId);
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

  /// Choix retenus tels que transmis, par leçon.
  final Map<String, int> quizChoices = {};

  /// Ce que le serveur rendrait à la relecture des réponses.
  Map<String, int?> remoteQuizAnswers = {};

  @override
  Future<void> reportQuizAnswer({
    required String lessonId,
    required String answeredOn,
    required bool correct,
    required int choiceIndex,
  }) async {
    _guard();
    quizReports.add((lessonId, answeredOn, correct));
    quizChoices[lessonId] = choiceIndex;
  }

  @override
  Future<Map<String, int?>> fetchQuizAnswers() async {
    _guard();
    return Map.of(remoteQuizAnswers);
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

  // ── Se protéger ─────────────────────────────────────────────────────────

  /// Identifiants reçus par [blockUser] / [unblockUser], dans l'ordre.
  final List<String> blockedIds = [];
  final List<String> unblockedIds = [];

  /// Signalements reçus, dans l'ordre.
  final List<FakeCommunityReport> reports = [];

  /// Identifiants reçus par [deleteEncouragement], dans l'ordre.
  final List<String> deletedEncouragements = [];

  /// Le nom affiché d'une personne connue du dépôt : un ami, ou l'auteur
  /// d'un mot du fil — qui peut ne plus être un ami du tout.
  String _displayNameOf(String userId) {
    for (final friend in _friends) {
      if (friend.id == userId) {
        return friend.displayName;
      }
    }
    for (final word in _feed) {
      if (word.fromUserId == userId) {
        return word.fromName;
      }
    }
    return 'Membre';
  }

  /// Comme le serveur : l'ami disparaît, ses mots aussi, la personne rejoint
  /// la liste des blocages sous son nom — que le serveur lit sur le compte,
  /// pas sur l'amitié.
  @override
  Future<void> blockUser(String userId) async {
    _guard();
    blockedIds.add(userId);
    final displayName = _displayNameOf(userId);
    _friends.removeWhere((friend) => friend.id == userId);
    _feed.removeWhere((word) => word.fromUserId == userId);
    _blocked.insert(
      0,
      BlockedUser(
        userId: userId,
        displayName: displayName,
        blockedAt: DateTime.now(),
      ),
    );
  }

  /// Débloquer ne rétablit rien : l'ami ne revient pas.
  @override
  Future<void> unblockUser(String userId) async {
    _guard();
    unblockedIds.add(userId);
    _blocked.removeWhere((blocked) => blocked.userId == userId);
  }

  @override
  Future<List<BlockedUser>> listBlocked() async {
    _guard();
    return List.unmodifiable(_blocked);
  }

  @override
  Future<void> reportUser(String userId, CommunityReportDraft report) async {
    _guard();
    reports.add((
      userId: userId,
      encouragementId: null,
      reason: report.reason,
      details: report.details,
    ));
  }

  @override
  Future<void> reportEncouragement(
    Encouragement encouragement,
    CommunityReportDraft report,
  ) async {
    _guard();
    reports.add((
      userId: encouragement.fromUserId,
      encouragementId: encouragement.id,
      reason: report.reason,
      details: report.details,
    ));
  }

  /// Signalements de DÉFI reçus, dans l'ordre : le défi, la personne visée
  /// (son créateur), le motif.
  final List<({String challengeId, String userId, String? details})>
  challengeReports = [];

  @override
  Future<void> reportFriendChallenge(
    FriendChallenge challenge,
    CommunityReportDraft report,
  ) async {
    _guard();
    challengeReports.add((
      challengeId: challenge.id,
      userId: challenge.creator?.userId ?? '',
      details: report.details,
    ));
  }

  @override
  Future<void> deleteEncouragement(String encouragementId) async {
    _guard();
    deletedEncouragements.add(encouragementId);
    _feed.removeWhere((word) => word.id == encouragementId);
  }

  // ── Défis entre amis ──────────────────────────────────────────────────

  /// Les défis en mémoire, pilotables par les tests.
  final List<FriendChallenge> friendChallengeList = [];

  @override
  Future<List<FriendChallenge>> friendChallenges() async {
    // Comme toute autre lecture : sans ce garde, la doublure prétendait
    // répondre alors que le dépôt est déclaré injoignable, et l'écran
    // n'avait jamais l'occasion de dire la panne.
    _guard();
    return List.unmodifiable(friendChallengeList);
  }

  @override
  Future<FriendChallenge> createFriendChallenge(
    String id,
    NewFriendChallenge challenge,
  ) async {
    final cree = FriendChallenge(
      id: id,
      title: challenge.title,
      metric: challenge.metric,
      unit: challenge.metric.label,
      target: challenge.target,
      status: FriendChallengeStatus.open,
      myStatus: FriendChallengeMemberStatus.accepted,
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(Duration(days: challenge.durationDays)),
      creatorDisplayName: 'Moi',
      members: const [],
    );
    friendChallengeList.add(cree);
    return cree;
  }

  @override
  Future<FriendChallenge> friendChallenge(String challengeId) async {
    _guard();
    for (final challenge in friendChallengeList) {
      if (challenge.id == challengeId) {
        return challenge;
      }
    }
    throw const ServerException('Défi introuvable.', statusCode: 404);
  }

  @override
  Future<FriendChallenge> acceptFriendChallenge(String challengeId) async {
    // La doublure ne recompose pas le classement : ce que les écrans
    // testent, c'est que le geste part et que la liste se relit.
    return friendChallengeList.firstWhere(
      (challenge) => challenge.id == challengeId,
    );
  }

  @override
  Future<void> declineFriendChallenge(String challengeId) async {
    friendChallengeList.removeWhere((challenge) => challenge.id == challengeId);
  }

  /// La LIGUE, pilotable : `joinsLeague` décide de ce que la lecture rend,
  /// comme le serveur — sans adhésion, le classement est VIDE.
  bool joinsLeague = false;
  League? leagueOverride;

  /// L'échec que la SEULE ligue oppose, sans faire tomber le reste : c'est
  /// ainsi qu'on vérifie qu'une source isolée entre bien dans l'arbitrage
  /// erreur / chargement / vide de l'écran.
  Object? leagueError;

  /// Combien de fois la ligue a été LUE : un rafraîchissement ne doit pas
  /// interroger une source qu'aucun onglet ouvert ne montre.
  int leagueReads = 0;

  @override
  Future<League> league() async {
    leagueReads++;
    _guard();
    final erreur = leagueError;
    if (erreur != null) {
      throw erreur;
    }
    final impose = leagueOverride;
    if (impose != null) {
      return impose;
    }
    return League(
      joined: joinsLeague,
      periodKey: '2026-W38',
      endsAt: DateTime.now().add(const Duration(days: 3)),
      division: LeagueDivision.bronze,
      score: 0,
      standings: const [],
    );
  }

  @override
  Future<League> setLeagueJoined(bool joined) async {
    joinsLeague = joined;
    leagueOverride = null;
    return league();
  }
}
