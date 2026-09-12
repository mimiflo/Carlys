/// Le monde communautaire D'EXEMPLE (doublure de test) : ses amis, ses mots, ses demandes,
/// ses défis et ses codes amis.
///
/// Séparé de `in_memory_community_repository.dart` : le COMPORTEMENT du dépôt (bloquer,
/// rejoindre, répondre) se lit d'un coup d'œil sans traverser cent lignes
/// de prénoms, et retoucher la vitrine ne fait plus bouger la logique.
///
/// Exception documentée à la règle « pas de données codées en dur » : ce jeu
/// n'est JAMAIS chargé en development, staging ou production — voir
/// les harnais de test qui montent l'écran Communauté.
///
/// Chaque fonction rend une collection NEUVE et modifiable : le dépôt en
/// mémoire la fait vivre pendant le test (retirer un ami, rejoindre un
/// défi), et deux instances ne se marchent pas dessus. Les dates sont
/// relatives à la construction, pour que le jeu d'exemple ne vieillisse jamais.
library;

import 'package:carlys_mobile/features/community/domain/entities/community.dart';

/// Les mots déjà reçus, du plus récent au plus ancien.
List<Encouragement> sampleEncouragements() => [
  Encouragement(
    id: 'exemple-encouragement-1',
    fromUserId: 'exemple-friend-sarah',
    fromName: 'Sarah',
    message: 'Belle série de 6 jours, continue comme ça ! 💪',
    sentAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  Encouragement(
    id: 'exemple-encouragement-2',
    fromUserId: 'exemple-friend-mehdi',
    fromName: 'Mehdi',
    message: 'Ton volume de la semaine est impressionnant.',
    sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
  ),
  Encouragement(
    id: 'exemple-encouragement-3',
    fromUserId: 'exemple-friend-lea',
    fromName: 'Léa',
    message: 'On se fait le défi du haut du corps ensemble ?',
    sentAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

/// Les amis de la visite, dont un profil privé : le jeu d'exemple montre les deux
/// rendus de la carte d'ami.
List<CommunityFriend> sampleFriends() => [
  const CommunityFriend(
    id: 'exemple-friend-sarah',
    displayName: 'Sarah',
    streakDays: 11,
    weeklySessions: 4,
    sharesProgress: true,
  ),
  const CommunityFriend(
    id: 'exemple-friend-mehdi',
    displayName: 'Mehdi',
    streakDays: 6,
    weeklySessions: 3,
    sharesProgress: true,
  ),
  const CommunityFriend(
    id: 'exemple-friend-lea',
    displayName: 'Léa',
    streakDays: 4,
    weeklySessions: 5,
    sharesProgress: true,
  ),
  // Profil privé : la progression n'a JAMAIS quitté le serveur — null,
  // pas zéro. L'écran ne montre que le nom.
  const CommunityFriend(
    id: 'exemple-friend-tom',
    displayName: 'Tom',
    streakDays: null,
    weeklySessions: null,
    sharesProgress: false,
  ),
];

/// Une demande en attente : la section « Demandes reçues » a de quoi vivre
/// dès l'ouverture.
List<FriendRequest> sampleFriendRequests() => [
  FriendRequest(
    id: 'exemple-request-nina',
    fromDisplayName: 'Nina',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
];

/// Les défis du mois, indexés par identifiant : un rejoint, deux non, et
/// les deux familles (sport, culture).
Map<String, CommunityChallenge> sampleChallenges() => {
  'exemple-challenge-squats': CommunityChallenge(
    id: 'exemple-challenge-squats',
    kind: ChallengeKind.sport,
    title: '10 000 squats à plusieurs',
    description:
        'Le groupe additionne ses répétitions de squat jusqu’à 10 000 avant la fin du mois.',
    participants: 47,
    progress: 0.62,
    joined: true,
    endsAt: DateTime.now().add(const Duration(days: 12)),
  ),
  'exemple-challenge-anatomie': CommunityChallenge(
    id: 'exemple-challenge-anatomie',
    kind: ChallengeKind.culture,
    title: 'Qui connaît le mieux le haut du corps ?',
    description:
        'Cinq questions d’anatomie par jour pendant une semaine. Le meilleur score gagne.',
    participants: 23,
    progress: 0.4,
    joined: false,
    endsAt: DateTime.now().add(const Duration(days: 5)),
  ),
  'exemple-challenge-constance': CommunityChallenge(
    id: 'exemple-challenge-constance',
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

/// Le code ami du visiteur — mêmes règles que le serveur : 8 caractères de
/// l'alphabet sans ambiguïté.
const String sampleMyFriendCode = 'CWDEM742';

/// Les seuls codes que le jeu d'exemple sait reconnaître, et le prénom derrière.
/// Tout autre code « ne mène à personne », comme sur le vrai serveur.
const Map<String, String> sampleKnownFriendCodes = {
  'AC23DEF4': 'Sarah',
  'MK78WXY2': 'Mehdi',
};
