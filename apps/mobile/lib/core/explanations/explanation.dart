/// Le POURQUOI d'une donnée affichée — le gabarit, jamais le contenu.
///
/// « Carlys ne dit jamais seulement quoi faire, il explique toujours
/// pourquoi. » Cette promesse ne concerne pas une fonctionnalité : elle vaut
/// pour un IMC comme pour un titre de progression. Le gabarit vit donc dans
/// `core/`, à côté de `core/brand/`, et chaque fonctionnalité garde SON
/// catalogue dans son propre domaine — l'enfermer dans l'une d'elles
/// obligerait les autres à en dépendre, ou pire, à s'en recopier une
/// deuxième version.
library;

/// Ce qu'on explique d'une donnée : ce qu'elle est, d'où elle sort, et — le
/// plus utile — ce qu'elle ne dit PAS.
class Explanation {
  const Explanation({
    required this.titre,
    required this.cequeCest,
    required this.douCaSort,
    this.cequeCaNeDitPas,
  });

  /// Nom de la donnée, tel qu'il est écrit à l'écran.
  final String titre;

  /// En une phrase, sans jargon.
  final String cequeCest;

  /// Le calcul réel, avec ses nombres. Pas une paraphrase : les chiffres qui
  /// figurent ici sont ceux que le serveur applique.
  final String douCaSort;

  /// Les limites, quand elles existent. C'est souvent la partie qui évite une
  /// mauvaise décision — un IMC pris au pied de la lettre par un pratiquant
  /// de force, une dépense estimée prise pour une mesure.
  final String? cequeCaNeDitPas;
}
