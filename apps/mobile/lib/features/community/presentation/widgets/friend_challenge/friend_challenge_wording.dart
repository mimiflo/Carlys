/// CE QU'UN DÉFI ENTRE AMIS DIT, en fonctions pures.
///
/// La maquette du 23 septembre 2026 promettait « +150 points pour chaque
/// participant » et « le défi est validé si tout le monde atteint
/// l'objectif ». Rien de tel n'existe, et le principe 5 l'interdit : un défi
/// entre amis CLASSE, il ne rapporte ni point ni titre
/// (`docs/product/community.md`). Ce fichier écrit donc la vraie règle du
/// jeu, et rien d'autre.
library;

import '../../../../../core/utilities/formatting.dart';
import '../../../domain/entities/friend_challenge.dart';

/// « J−6 », « Dernier jour » ou « Terminé » — le signe MOINS (U+2212),
/// comme la ligue et les défis du mois.
String friendChallengeCountdown(FriendChallenge challenge) {
  if (challenge.isOver) {
    return 'Terminé';
  }
  final days = challenge.daysLeft;
  return days <= 0 ? 'Dernier jour' : 'J\u2212$days';
}

/// Qui a lancé le défi, vu par moi.
String friendChallengeOrigin(FriendChallenge challenge) {
  final creator = challenge.creator;
  if (creator != null && creator.isMe) {
    return 'Tu as lancé ce défi';
  }
  return challenge.isPending
      ? '${challenge.creatorDisplayName} te défie'
      : 'Lancé par ${challenge.creatorDisplayName}';
}

/// Une quantité dans l'unité du défi, lisible : des minutes plutôt que des
/// secondes, des kilomètres au-delà du kilomètre.
String friendChallengeAmount(ChallengeMetric metric, int value) {
  return switch (metric) {
    ChallengeMetric.workouts =>
      '${formatThousands(value)} ${value <= 1 ? 'séance' : 'séances'}',
    ChallengeMetric.quizCorrect =>
      '${formatThousands(value)} '
          '${value <= 1 ? 'bonne réponse' : 'bonnes réponses'}',
    ChallengeMetric.activeSeconds => _effort(value),
    ChallengeMetric.distanceMeters =>
      value >= 1000
          ? '${formatDecimal(value / 1000)} km'
          : '${formatThousands(value)} m',
  };
}

/// Des minutes, puis des heures : « 45 min », « 1 h 05 ». Écrit en prose,
/// pas en capitales mono comme les chronos de séance.
String _effort(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    return '$minutes min';
  }
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
}

/// Une tuile de la rangée de faits : une valeur, et ce qu'elle mesure.
typedef FriendChallengeFact = ({String value, String label});

/// L'objectif : commun (« 5 séances »), ou « le plus » quand il n'y en a
/// pas — c'est alors celui qui en fait le plus qui mène.
FriendChallengeFact friendChallengeGoal(FriendChallenge challenge) {
  final target = challenge.target;
  if (target == null) {
    return (value: 'Le plus', label: _metricNoun(challenge.metric));
  }
  final amount = friendChallengeAmount(challenge.metric, target);
  final space = amount.indexOf(' ');
  return space < 0
      ? (value: amount, label: 'à atteindre')
      : (value: amount.substring(0, space), label: amount.substring(space + 1));
}

/// La durée choisie ; déduite des bornes pour un serveur plus ancien.
FriendChallengeFact friendChallengeDuration(FriendChallenge challenge) {
  final days =
      challenge.durationDays ??
      challenge.endsAt.difference(challenge.startsAt).inHours ~/ 24;
  return (value: '$days', label: days <= 1 ? 'jour' : 'jours');
}

/// Ce qui compte, en deux mots.
FriendChallengeFact friendChallengeCounts(ChallengeMetric metric) {
  return switch (metric) {
    ChallengeMetric.workouts => (value: 'Tous types', label: 'de séances'),
    ChallengeMetric.activeSeconds => (value: 'Effort', label: 'chronométré'),
    ChallengeMetric.distanceMeters => (value: 'Distance', label: 'parcourue'),
    ChallengeMetric.quizCorrect => (value: 'Academy', label: 'bonnes réponses'),
  };
}

String _metricNoun(ChallengeMetric metric) => switch (metric) {
  ChallengeMetric.workouts => 'de séances',
  ChallengeMetric.activeSeconds => 'd’effort',
  ChallengeMetric.distanceMeters => 'de distance',
  ChallengeMetric.quizCorrect => 'de bonnes réponses',
};

/// La règle du jeu, ligne à ligne : ce qui compte, comment le classement
/// vit, l'objectif, et ce qui n'est PAS en jeu.
List<String> friendChallengeRules(FriendChallenge challenge) {
  final target = challenge.target;
  return [
    switch (challenge.metric) {
      ChallengeMetric.workouts =>
        'Chaque séance terminée compte, quel que soit son type.',
      ChallengeMetric.activeSeconds =>
        'Chaque minute d’effort chronométrée pendant une séance compte.',
      ChallengeMetric.distanceMeters =>
        'Chaque mètre parcouru pendant une séance compte.',
      ChallengeMetric.quizCorrect =>
        'Chaque bonne réponse du jour à l’Academy compte.',
    },
    'On entre au classement en acceptant, à zéro. Il bouge à chaque effort '
        'et se fige à la fin du défi.',
    if (target == null)
      'Pas d’objectif fixé : celui qui en fait le plus mène.'
    else
      'Objectif commun : '
          '${friendChallengeAmount(challenge.metric, target)}. Chacun voit '
          'qui l’a atteint.',
    'Aucun point ni titre en jeu : juste toi et tes amis.',
  ];
}

/// Le statut d'un participant, dit sans genrer personne.
String friendChallengeMemberStatus(FriendChallengeMember member) {
  if (member.isCreator) {
    return 'À l’origine';
  }
  return switch (member.status) {
    FriendChallengeMemberStatus.accepted => 'Dans le défi',
    FriendChallengeMemberStatus.invited => 'En attente',
    FriendChallengeMemberStatus.declined => 'A refusé',
    FriendChallengeMemberStatus.left => 'A quitté',
  };
}

/// « Aujourd’hui, 08h24 » : l'heure du message, en heure LOCALE.
String friendChallengeMessageTime(DateTime createdAt, {DateTime? now}) {
  final local = createdAt.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  return '${formatSpokenDay(local, reference)}, ${formatClock(local)}';
}
