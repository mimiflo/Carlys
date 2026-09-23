/// Communauté D'EXEMPLE (doublure de test) : le COMPORTEMENT du dépôt, en mémoire.
///
/// Même règle que les autres dépôts d'exemple : l'état vit le temps du
/// processus, rejoindre un défi, répondre à une demande, envoyer un
/// encouragement ou bloquer quelqu'un se voit immédiatement, rien ne touche
/// le réseau.
///
/// Le monde lui-même (amis, mots, demandes, défis, codes) est dans
/// `community_sample_world.dart` : ce fichier ne décrit que ce qui ARRIVE quand
/// on y touche.
library;

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/domain/entities/community_moderation.dart';
import 'package:carlys_mobile/features/community/domain/entities/friend_challenge.dart';
import 'package:carlys_mobile/features/community/domain/entities/league.dart';
import 'package:carlys_mobile/features/community/domain/friend_code.dart';
import 'package:carlys_mobile/features/community/domain/repositories/community_repository.dart';
import 'community_sample_world.dart';

class InMemoryCommunityRepository implements CommunityRepository {
  final List<Encouragement> _received = sampleEncouragements();
  final List<CommunityFriend> _friends = sampleFriends();
  final List<FriendRequest> _requests = sampleFriendRequests();
  final Map<String, CommunityChallenge> _challenges = sampleChallenges();

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
  Future<String> myFriendCode() async => sampleMyFriendCode;

  @override
  Future<String?> lookupFriendCode(String code) async {
    final normalized = normalizeFriendCode(code);
    return normalized == null ? null : sampleKnownFriendCodes[normalized];
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
          id: 'exemple-friend-${_nextId++}',
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

  /// Les encouragements ENVOYÉS, que le fil ne montre jamais.
  final List<({String friendId, String message})> sent = [];

  @override
  Future<void> encourage(String friendId, String message) async {
    // Le fil ne sert que les mots REÇUS : un encouragement envoyé n'y entre
    // pas. Le double le faisait entrer, sous la forme d'un merci immédiat —
    // une amabilité qui donnait au geste un retour que la vraie application
    // n'a pas, et qui masquait justement son absence de retour.
    _friends.firstWhere((f) => f.id == friendId);
    sent.add((friendId: friendId, message: message));
  }

  @override
  Future<void> reportQuizAnswer({
    required String lessonId,
    required String answeredOn,
    required bool correct,
    required int choiceIndex,
  }) async {
    // Pas d'objectif chiffré derrière ses barres : la réponse
    // est acceptée et c'est tout — le vrai comptage est serveur.
  }

  @override
  Future<Map<String, int?>> fetchQuizAnswers() async => const {};

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
      return; // Personne inconnue du monde d'exemple : rien à retirer.
    }
    _friends.removeWhere((friend) => friend.id == userId);
    _received.removeWhere((word) => word.fromUserId == userId);
    _blocked.insert(
      0,
      BlockedUser(userId: userId, displayName: name, blockedAt: DateTime.now()),
    );
  }

  /// Le nom affiché d'une personne du monde d'exemple : un ami, ou l'auteur
  /// d'un mot du fil. `null` si le jeu d'exemple ne la connaît pas.
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
    // Le signalement part vers l'équipe : en exemple comme en vrai, rien à
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

  // ── Défis entre amis ──────────────────────────────────────────────────

  /// Les défis ENTRE AMIS de l'exemple (`sampleFriendChallenges`).
  final List<FriendChallenge> friendChallengeList = sampleFriendChallenges();

  /// Les signalements de défi reçus, dans l'ordre : identifiant du défi.
  final List<String> reportedFriendChallenges = [];

  @override
  Future<List<FriendChallenge>> friendChallenges() async =>
      List.unmodifiable(friendChallengeList);

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
      createdAt: DateTime.now(),
      durationDays: challenge.durationDays,
      creatorDisplayName: 'Moi',
      message: challenge.message,
      members: const [
        FriendChallengeMember(
          userId: 'exemple-moi',
          displayName: 'Camille',
          status: FriendChallengeMemberStatus.accepted,
          contribution: 0,
          rank: 1,
          isMe: true,
          isCreator: true,
        ),
      ],
    );
    friendChallengeList.add(cree);
    return cree;
  }

  @override
  Future<FriendChallenge> friendChallenge(String challengeId) async {
    for (final challenge in friendChallengeList) {
      if (challenge.id == challengeId) {
        return challenge;
      }
    }
    // Comme le serveur : un défi quitté ou refusé n'est plus lisible.
    throw const ServerException('Défi introuvable.', statusCode: 404);
  }

  @override
  Future<FriendChallenge> acceptFriendChallenge(String challengeId) async {
    // J'entre au classement, à zéro, derrière ceux qui ont déjà marqué :
    // l'écran de détail relit le défi et doit voir le geste pris.
    final index = friendChallengeList.indexWhere(
      (challenge) => challenge.id == challengeId,
    );
    final avant = friendChallengeList[index];
    final classes = avant.members.where((m) => m.rank != null).length;
    final apres = FriendChallenge(
      id: avant.id,
      title: avant.title,
      metric: avant.metric,
      unit: avant.unit,
      target: avant.target,
      status: avant.status,
      myStatus: FriendChallengeMemberStatus.accepted,
      startsAt: avant.startsAt,
      endsAt: avant.endsAt,
      createdAt: avant.createdAt,
      durationDays: avant.durationDays,
      creatorDisplayName: avant.creatorDisplayName,
      message: avant.message,
      members: [
        for (final member in avant.members)
          member.isMe
              ? FriendChallengeMember(
                  userId: member.userId,
                  displayName: member.displayName,
                  status: FriendChallengeMemberStatus.accepted,
                  contribution: 0,
                  rank: classes + 1,
                  isMe: true,
                  isCreator: member.isCreator,
                )
              : member,
      ],
    );
    friendChallengeList[index] = apres;
    return apres;
  }

  @override
  Future<void> reportFriendChallenge(
    FriendChallenge challenge,
    CommunityReportDraft report,
  ) async {
    reportedFriendChallenges.add(challenge.id);
  }

  @override
  Future<void> declineFriendChallenge(String challengeId) async {
    friendChallengeList.removeWhere((challenge) => challenge.id == challengeId);
  }

  League _league = sampleLeague();

  @override
  Future<League> league() async => _league;

  @override
  Future<League> setLeagueJoined(bool joined) async {
    final vue = _league;
    // Sortir VIDE le classement, comme le serveur : sans adhésion, on ne
    // montre pas des noms d'inconnus. Le score de la semaine, lui, ne
    // s'efface pas — la sortie arrête le compte, elle ne réécrit rien.
    _league = League(
      joined: joined,
      periodKey: vue.periodKey,
      endsAt: vue.endsAt,
      division: vue.division,
      score: vue.score,
      standings: joined ? sampleLeague().standings : const [],
      lastResult: joined ? vue.lastResult : null,
      // Sans adhésion, ni classement ni zone : le serveur rend `null`.
      promotion: joined ? sampleLeague().promotion : null,
    );
    return _league;
  }
}
