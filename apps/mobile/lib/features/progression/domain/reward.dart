/// LES RÉCOMPENSES : ce qui reste quand les points redescendent.
///
/// ## Deux mémoires, et c'est tout le sujet
///
/// Le profil de progression est DÉRIVÉ : il se recalcule sur une fenêtre
/// récente, donc il monte quand on s'entraîne et il redescend quand on
/// s'arrête. C'est l'état du moment, et il doit rester honnête.
///
/// Les récompenses, elles, sont un JOURNAL. Une médaille obtenue le reste
/// pour toujours, même après trois mois d'arrêt, même si le fait qui l'a
/// value est sorti de la fenêtre. La dérivation ne fait qu'AJOUTER : elle ne
/// retire jamais rien.
///
/// C'est la réponse exacte à la règle de la marque — « la progression doit
/// rester positive après une interruption, Carlys conserve l'histoire de
/// l'utilisateur plutôt que punir ses absences ». Ce qui bouge est le
/// présent ; ce qui est gagné est l'histoire, et l'histoire ne se reprend
/// pas.
///
/// ## Pourquoi des formes différentes
///
/// Un badge, une médaille et un certificat ne récompensent pas la même
/// chose. Le badge marque un premier pas, la médaille un cap tenu, le
/// certificat un engagement long. Tout mettre sous une seule forme
/// reviendrait à dire que la première leçon vaut le pack entier.
library;

import '../../../core/brand/carlys_value.dart';

export '../../../core/brand/carlys_value.dart' show CarlysValue;

/// Les formes de récompense.
enum RewardKind {
  /// Un premier pas franchi. Se gagne vite, et c'est voulu : la marque dit
  /// « essayer plutôt que réussir parfaitement ».
  badge('Badge', 'Badges'),

  /// Un cap tenu dans la durée.
  medaille('Médaille', 'Médailles'),

  /// Un engagement long mené à son terme.
  certificat('Certificat', 'Certificats'),

  /// Une charge, un volume ou des répétitions jamais atteints. Il ne vient
  /// pas d'un barème : c'est un fait mesuré pendant une séance.
  record('Record', 'Records personnels'),

  /// Un palier du profil. Inscrit au journal le jour où il est atteint, il
  /// ne se perd donc pas si les points redescendent.
  titre('Titre', 'Titres');

  const RewardKind(this.label, this.plural);

  final String label;
  final String plural;
}

/// Une récompense du catalogue.
class Reward {
  const Reward({
    required this.id,
    required this.kind,
    required this.label,
    required this.story,
    this.value,
    this.figure,
  });

  /// Identifiant STABLE : c'est la clé du journal. Le renommer ferait
  /// disparaître une récompense déjà obtenue, ce qui est interdit.
  final String id;

  final RewardKind kind;

  /// Ce qui est écrit sur la récompense.
  final String label;

  /// Ce qui a été fait pour l'obtenir, en une phrase. Une récompense sans
  /// histoire n'est qu'une pastille.
  final String story;

  /// La valeur de marque à laquelle elle se rattache. `null` pour les titres,
  /// qui tiennent aux cinq à la fois.
  final CarlysValue? value;

  /// Ce qui est FRAPPÉ au centre du sceau : « 80 » pour un record, « IV »
  /// pour un titre. `null` quand la forme parle d'elle-même et porte son
  /// glyphe — un badge n'a pas de chiffre à montrer.
  final String? figure;
}

/// Une récompense OBTENUE, avec la date de son obtention.
class EarnedReward {
  const EarnedReward({
    required this.reward,
    required this.earnedAt,
    this.isNew = false,
  });

  final Reward reward;

  /// Date de PREMIÈRE obtention, telle que le journal l'a inscrite. Elle ne
  /// change plus jamais : regagner un cap ne réécrit pas l'histoire.
  final DateTime earnedAt;

  /// Obtenue à l'instant, pendant cette session d'utilisation. C'est le seul
  /// cas où la récompense se GRAVE sous les yeux : rejouer l'animation à
  /// chaque ouverture la viderait de son sens.
  final bool isNew;
}
