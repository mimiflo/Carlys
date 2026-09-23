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
import 'package:carlys_mobile/features/community/domain/entities/friend_challenge.dart';
import 'package:carlys_mobile/features/community/domain/entities/league.dart';

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
    target: 10000,
    totalContribution: 6200,
    unit: 'répétitions',
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
    target: 300,
    totalContribution: 120,
    unit: 'bonnes réponses',
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
    target: 500000,
    totalContribution: 390000,
    unit: 'mètres',
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

/// La ligue d'exemple : la division Bronze de la maquette du 23 septembre
/// 2026, en pleine semaine.
///
/// REJOINTE dans le monde d'exemple, parce que l'écran à montrer est le
/// classement : la carte d'invitation, elle, se lit en un paragraphe et
/// n'apprend rien sur la mise en page d'un tableau.
///
/// Douze joueurs ont marqué : la semaine COMPTE (il en faut dix). Je suis
/// 7e avec 240 points ; le 5e en a 275 — il m'en manque 35 pour la zone de
/// montée. Le bloc `promotion` est celui que le serveur calculerait pour
/// ces scores (`promotionOutlook`, `league-ladder.ts`), recopié ici à la
/// main : c'est une doublure, pas une seconde implémentation de la règle.
League sampleLeague() => League(
  joined: true,
  periodKey: '2026-W39',
  endsAt: DateTime.now().add(const Duration(days: 2, hours: 6)),
  division: LeagueDivision.bronze,
  score: 240,
  standings: [
    for (final (index, (id, name, score)) in _classement.indexed)
      LeagueStanding(
        userId: id,
        displayName: name,
        score: score,
        rank: index + 1,
        isMe: id == 'exemple-moi',
      ),
  ],
  promotion: const LeaguePromotion(
    promotedCount: 5,
    minPlayers: 10,
    activePlayers: 12,
    topDivision: false,
    inZone: false,
    zoneScore: 275,
    pointsToZone: 35,
  ),
);

/// La division de la semaine, déjà triée : aucun ex æquo, pour que le rang
/// se lise sans règle de départage.
const List<(String, String, int)> _classement = [
  ('exemple-sarah', 'Sarah', 480),
  ('exemple-mehdi', 'Mehdi', 355),
  ('exemple-lea', 'Léa', 300),
  ('exemple-ines', 'Inès', 290),
  ('exemple-tom', 'Tom', 275),
  ('exemple-chloe', 'Chloé', 260),
  ('exemple-moi', 'Camille', 240),
  ('exemple-hugo', 'Hugo', 210),
  ('exemple-nora', 'Nora', 180),
  ('exemple-yanis', 'Yanis', 150),
  ('exemple-jade', 'Jade', 120),
  ('exemple-lucas', 'Lucas', 95),
];

/// Les défis ENTRE AMIS de l'exemple, lancés par des amis du jeu (Sarah,
/// Léa) : un en cours où l'on est deuxième, et une invitation en attente —
/// celle de la maquette du 23 septembre 2026, message compris.
List<FriendChallenge> sampleFriendChallenges() {
  final now = DateTime.now();
  return [
    FriendChallenge(
      id: 'exemple-defi-ami-course',
      title: 'Qui court le plus',
      metric: ChallengeMetric.distanceMeters,
      unit: 'mètres',
      status: FriendChallengeStatus.open,
      myStatus: FriendChallengeMemberStatus.accepted,
      startsAt: now.subtract(const Duration(days: 2)),
      endsAt: now.add(const Duration(days: 5)),
      createdAt: now.subtract(const Duration(days: 2)),
      durationDays: 7,
      creatorDisplayName: 'Sarah',
      members: const [
        FriendChallengeMember(
          userId: 'exemple-friend-sarah',
          displayName: 'Sarah',
          status: FriendChallengeMemberStatus.accepted,
          contribution: 12400,
          rank: 1,
          isMe: false,
          isCreator: true,
        ),
        FriendChallengeMember(
          userId: 'exemple-moi',
          displayName: 'Camille',
          status: FriendChallengeMemberStatus.accepted,
          contribution: 9800,
          rank: 2,
          isMe: true,
        ),
        FriendChallengeMember(
          userId: 'exemple-friend-tom',
          displayName: 'Tom',
          status: FriendChallengeMemberStatus.accepted,
          contribution: 4200,
          rank: 3,
          isMe: false,
        ),
      ],
    ),
    FriendChallenge(
      id: 'exemple-defi-ami-seances',
      title: 'Cinq séances cette semaine',
      metric: ChallengeMetric.workouts,
      unit: 'séances',
      target: 5,
      status: FriendChallengeStatus.open,
      myStatus: FriendChallengeMemberStatus.invited,
      startsAt: now.subtract(const Duration(hours: 5)),
      endsAt: now.add(const Duration(days: 6, hours: 19)),
      createdAt: now.subtract(const Duration(hours: 5)),
      durationDays: 7,
      creatorDisplayName: 'Léa',
      message:
          'Allez on y va ! 5 séances cette semaine, on se motive et on se '
          'tient au courant 💪',
      members: const [
        FriendChallengeMember(
          userId: 'exemple-friend-lea',
          displayName: 'Léa',
          status: FriendChallengeMemberStatus.accepted,
          contribution: 2,
          rank: 1,
          isMe: false,
          isCreator: true,
        ),
        FriendChallengeMember(
          userId: 'exemple-friend-mehdi',
          displayName: 'Mehdi',
          status: FriendChallengeMemberStatus.accepted,
          contribution: 1,
          rank: 2,
          isMe: false,
        ),
        FriendChallengeMember(
          userId: 'exemple-moi',
          displayName: 'Camille',
          status: FriendChallengeMemberStatus.invited,
          contribution: 0,
          isMe: true,
        ),
      ],
    ),
  ];
}
