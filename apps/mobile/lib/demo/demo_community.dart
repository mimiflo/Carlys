/// Communauté du MODE DÉMO : des amis, des mots, des défis — en mémoire.
///
/// Même règle que les autres dépôts de démonstration : l'état vit le temps du
/// processus, rejoindre un défi, répondre à une demande ou envoyer un
/// encouragement se voit immédiatement, rien ne touche le réseau.
library;

import '../features/community/domain/entities/community.dart';
import '../features/community/domain/repositories/community_repository.dart';

class DemoCommunityRepository implements CommunityRepository {
  final List<Encouragement> _received = [
    Encouragement(
      id: 'demo-encouragement-1',
      fromName: 'Sarah',
      message: 'Belle série de 6 jours, continue comme ça ! 💪',
      sentAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Encouragement(
      id: 'demo-encouragement-2',
      fromName: 'Mehdi',
      message: 'Ton volume de la semaine est impressionnant.',
      sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    ),
    Encouragement(
      id: 'demo-encouragement-3',
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
          'Cinq questions d’anatomie par jour pendant une semaine — le meilleur score gagne.',
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

  bool _sharesProgress = true;
  int _nextId = 0;

  @override
  Future<List<Encouragement>> encouragements() async =>
      [..._received]..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  @override
  Future<List<CommunityFriend>> friends() async => [..._friends]
    ..sort((a, b) => (b.streakDays ?? -1).compareTo(a.streakDays ?? -1));

  @override
  Future<List<FriendRequest>> receivedRequests() async => [..._requests];

  @override
  Future<void> sendFriendRequest(String email) async {
    // Réponse opaque, comme le vrai serveur : rien ne se passe de visible.
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
}
