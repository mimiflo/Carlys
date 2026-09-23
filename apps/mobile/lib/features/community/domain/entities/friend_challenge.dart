/// DÉFIS ENTRE AMIS : individuels, invités un par un, clos tout seuls.
///
/// Trois choses les séparent des défis collectifs, et ce sont elles qui ont
/// justifié des tables séparées côté serveur : on n'y entre que sur
/// invitation, le classement est INDIVIDUEL (partir en retire, là où quitter
/// un défi collectif laisse sa contribution au groupe), et la fin produit un
/// résultat figé.
library;

/// Ce qu'un défi compte — la même liste que les défis collectifs, et c'est
/// voulu : une séance ne doit pas compter différemment selon la famille.
enum ChallengeMetric {
  workouts('WORKOUTS', 'Séances terminées'),
  quizCorrect('QUIZ_CORRECT', 'Bonnes réponses'),
  activeSeconds('ACTIVE_SECONDS', 'Secondes d’effort'),
  distanceMeters('DISTANCE_METERS', 'Mètres parcourus');

  const ChallengeMetric(this.apiValue, this.label);

  final String apiValue;

  /// Ce que la personne LIT en choisissant sa métrique.
  final String label;

  static ChallengeMetric fromApi(String? value) {
    for (final metric in ChallengeMetric.values) {
      if (metric.apiValue == value) {
        return metric;
      }
    }
    // Un serveur plus récent peut compter une chose que cette version
    // ignore : le défi reste lisible, seule la métrique se dégrade.
    return ChallengeMetric.workouts;
  }
}

enum FriendChallengeStatus {
  open('OPEN'),
  closed('CLOSED'),
  cancelled('CANCELLED');

  const FriendChallengeStatus(this.apiValue);

  final String apiValue;

  static FriendChallengeStatus fromApi(String? value) {
    for (final status in FriendChallengeStatus.values) {
      if (status.apiValue == value) {
        return status;
      }
    }
    return FriendChallengeStatus.open;
  }
}

enum FriendChallengeMemberStatus {
  invited('INVITED'),
  accepted('ACCEPTED'),
  declined('DECLINED'),
  left('LEFT');

  const FriendChallengeMemberStatus(this.apiValue);

  final String apiValue;

  static FriendChallengeMemberStatus fromApi(String? value) {
    for (final status in FriendChallengeMemberStatus.values) {
      if (status.apiValue == value) {
        return status;
      }
    }
    return FriendChallengeMemberStatus.invited;
  }
}

/// Une ligne du classement : qui, combien, et à quelle place.
class FriendChallengeMember {
  const FriendChallengeMember({
    required this.userId,
    required this.displayName,
    required this.status,
    required this.contribution,
    required this.isMe,
    this.rank,
    this.isCreator = false,
  });

  final String userId;
  final String displayName;
  final FriendChallengeMemberStatus status;
  final int contribution;

  /// `null` pour qui n'a pas accepté, ou qui est parti : on ne classe pas
  /// quelqu'un qui n'a rien accepté, et partir sort du classement.
  final int? rank;
  final bool isMe;

  /// Celui qui a lancé le défi : l'initiateur, et l'auteur du titre et du
  /// message — c'est lui qu'un signalement vise.
  final bool isCreator;
}

class FriendChallenge {
  const FriendChallenge({
    required this.id,
    required this.title,
    required this.metric,
    required this.unit,
    required this.status,
    required this.myStatus,
    required this.startsAt,
    required this.endsAt,
    required this.creatorDisplayName,
    required this.members,
    this.target,
    this.message,
    this.createdAt,
    this.durationDays,
  });

  final String id;
  final String title;
  final ChallengeMetric metric;

  /// L'unité en toutes lettres, servie par le serveur : « mètres »,
  /// « séances ». Deux endroits où la nommer, c'est un endroit de trop.
  final String unit;

  /// Objectif commun, ou `null` : c'est alors « qui en fait le plus ».
  final int? target;
  final FriendChallengeStatus status;
  final FriendChallengeMemberStatus myStatus;
  final DateTime startsAt;
  final DateTime endsAt;
  final String creatorDisplayName;
  final List<FriendChallengeMember> members;

  /// Le mot du créateur, facultatif (280 caractères au plus), visible des
  /// seuls membres. `null` s'il n'a rien écrit — ou si le serveur est plus
  /// ancien que le champ.
  final String? message;

  /// L'heure du lancement, donc celle du message. `null` sur un serveur plus
  /// ancien : l'écran tait alors l'heure plutôt que d'en inventer une.
  final DateTime? createdAt;

  /// 3, 7 ou 30 jours, tels que choisis. `null` sur un serveur plus ancien.
  final int? durationDays;

  /// Le créateur, parmi les membres.
  FriendChallengeMember? get creator {
    for (final member in members) {
      if (member.isCreator) {
        return member;
      }
    }
    return null;
  }

  /// Ceux qui sont DANS le défi ou y sont attendus : les acceptés et les
  /// invités. Qui a refusé ou quitté n'est plus un participant.
  List<FriendChallengeMember> get participants => members
      .where(
        (member) =>
            member.status == FriendChallengeMemberStatus.accepted ||
            member.status == FriendChallengeMemberStatus.invited,
      )
      .toList(growable: false);

  /// Ma ligne du classement, s'il y en a une.
  FriendChallengeMember? get me {
    for (final member in members) {
      if (member.isMe) {
        return member;
      }
    }
    return null;
  }

  /// Le classement affichable : ceux qui ont accepté, dans l'ordre du
  /// serveur (contribution décroissante). Les invités en attente et les
  /// partants n'y figurent pas — ils n'ont pas de rang.
  List<FriendChallengeMember> get ranked =>
      members.where((member) => member.rank != null).toList(growable: false);

  bool get isPending => myStatus == FriendChallengeMemberStatus.invited;
  bool get isOver => status != FriendChallengeStatus.open;

  /// Jours restants, jamais négatif : un défi fini n'a plus de compte à
  /// rebours, il a un résultat.
  int get daysLeft {
    final reste = endsAt.difference(DateTime.now()).inDays;
    return reste < 0 ? 0 : reste;
  }
}

/// Ce qu'il faut pour lancer un défi. L'identifiant naît sur l'appareil :
/// rejouer la création après une coupure ne pose pas un second défi.
class NewFriendChallenge {
  const NewFriendChallenge({
    required this.title,
    required this.metric,
    required this.durationDays,
    required this.invitedUserIds,
    this.target,
    this.message,
  });

  final String title;
  final ChallengeMetric metric;

  /// 3, 7 ou 30 — les trois durées offertes. Un défi « entre amis » de
  /// quatre cents jours n'est plus un défi, c'est une dette.
  final int durationDays;
  final int? target;
  final List<String> invitedUserIds;

  /// Le mot facultatif qui accompagne l'invitation (280 caractères au plus).
  final String? message;
}
