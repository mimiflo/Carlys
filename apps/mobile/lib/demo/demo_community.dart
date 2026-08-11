/// Communauté du MODE DÉMO : des amis, des mots, des défis — en mémoire.
///
/// Même règle que les autres dépôts de démonstration : l'état vit le temps du
/// processus, rejoindre un défi ou envoyer un encouragement se voit
/// immédiatement, rien ne touche le réseau.
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

  final List<CommunityFriend> _friends = const [
    CommunityFriend(
      id: 'demo-friend-sarah',
      displayName: 'Sarah',
      streakDays: 11,
      weeklySessions: 4,
      sharesProgress: true,
    ),
    CommunityFriend(
      id: 'demo-friend-mehdi',
      displayName: 'Mehdi',
      streakDays: 6,
      weeklySessions: 3,
      sharesProgress: true,
    ),
    CommunityFriend(
      id: 'demo-friend-lea',
      displayName: 'Léa',
      streakDays: 4,
      weeklySessions: 5,
      sharesProgress: true,
    ),
    // Profil privé : la progression n'est PAS partagée — l'écran ne montre
    // que le nom, c'est la séparation public/privé rendue visible.
    CommunityFriend(
      id: 'demo-friend-tom',
      displayName: 'Tom',
      streakDays: 0,
      weeklySessions: 0,
      sharesProgress: false,
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

  int _nextId = 0;

  @override
  Future<List<Encouragement>> encouragements() async =>
      [..._received]..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  @override
  Future<List<CommunityFriend>> friends() async =>
      [..._friends]..sort((a, b) => b.streakDays.compareTo(a.streakDays));

  @override
  Future<List<CommunityChallenge>> challenges() async =>
      _challenges.values.toList()..sort((a, b) => a.endsAt.compareTo(b.endsAt));

  @override
  Future<CommunityChallenge> toggleChallenge(String challengeId) async {
    final challenge = _challenges[challengeId];
    if (challenge == null) {
      throw ArgumentError.value(challengeId, 'challengeId', 'défi inconnu');
    }
    final updated = challenge.copyWith(
      joined: !challenge.joined,
      participants: challenge.participants + (challenge.joined ? -1 : 1),
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
}
