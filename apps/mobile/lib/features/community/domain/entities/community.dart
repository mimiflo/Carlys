/// La communauté : amis, encouragements, défis.
///
/// Les entités séparent nettement le PUBLIC du PRIVÉ : un profil d'ami
/// n'expose que ce que son propriétaire a choisi de montrer — le reste
/// n'existe tout simplement pas dans l'entité.
library;

/// Un ami, vu à travers son PROFIL PUBLIC uniquement.
///
/// Volontairement pauvre : ni courriel, ni mesures corporelles, ni détail des
/// séances. Ce qui n'est pas dans cette entité ne peut pas fuiter à l'écran.
class CommunityFriend {
  const CommunityFriend({
    required this.id,
    required this.displayName,
    required this.streakDays,
    required this.weeklySessions,
    required this.sharesProgress,
  });

  final String id;
  final String displayName;

  /// Jours de série en cours — la statistique sociale par excellence.
  final int streakDays;

  /// Séances de la semaine, si l'ami partage sa progression.
  final int weeklySessions;

  /// L'ami a choisi de rendre sa progression visible. À faux, les compteurs
  /// valent zéro et l'interface n'affiche QUE le nom.
  final bool sharesProgress;
}

/// Un encouragement reçu — le petit mot qui fait tenir la série.
class Encouragement {
  const Encouragement({
    required this.id,
    required this.fromName,
    required this.message,
    required this.sentAt,
  });

  final String id;
  final String fromName;
  final String message;
  final DateTime sentAt;
}

/// Nature d'un défi : sportif (faire) ou culturel (savoir).
enum ChallengeKind {
  sport('Sportif'),
  culture('Culturel');

  const ChallengeKind(this.label);

  final String label;
}

/// Un défi de la communauté, individuel ou collectif.
class CommunityChallenge {
  const CommunityChallenge({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.participants,
    required this.progress,
    required this.joined,
    required this.endsAt,
  });

  final String id;
  final ChallengeKind kind;
  final String title;
  final String description;
  final int participants;

  /// Progression COLLECTIVE, de 0 à 1 : la somme des efforts du groupe.
  final double progress;

  /// L'utilisateur y participe.
  final bool joined;

  final DateTime endsAt;

  CommunityChallenge copyWith({int? participants, bool? joined}) {
    return CommunityChallenge(
      id: id,
      kind: kind,
      title: title,
      description: description,
      participants: participants ?? this.participants,
      progress: progress,
      joined: joined ?? this.joined,
      endsAt: endsAt,
    );
  }
}
