/// Où en est la lecture du pack — un REPÈRE, jamais un second score.
///
/// La règle de non-concurrence (`docs/product/progression.md`) l'impose, et
/// elle est chiffrée : l'axe « Maîtrise » du profil rapporte déjà les leçons
/// répondues à une cible FIXE de 20, quand le pack en compte 38. Un
/// pourcentage global affiché ici dirait « 53 % » à quelqu'un que son profil
/// annonce à « Maîtrise 100 % », au même instant et pour le même travail.
///
/// L'Academy compte donc dans l'unité de ce qu'elle compte : des LEÇONS.
/// « 24 sur 38 », « 4 sur 5 en Nutrition ». Une jauge par domaine reste une
/// position dans un contenu, pas une note sur la personne.
///
/// « Abordée » et non « réussie » : le moteur de progression a déjà tranché
/// dans l'autre sens, et l'a documenté — se tromper fait apprendre, et
/// n'ouvrir l'axe qu'aux bonnes réponses transformerait l'Academy en examen.
/// Compter autrement ici contredirait une règle écrite.
library;

import 'entities/academy.dart';

/// L'avancement d'un domaine : ce qui est abordé sur ce qu'il contient.
class DomainProgress {
  const DomainProgress({required this.abordees, required this.total});

  final int abordees;
  final int total;

  /// Part du domaine parcourue, de 0 à 1. Sert la JAUGE, pas un chiffre
  /// affiché : c'est une position dans un contenu.
  double get ratio => total == 0 ? 0 : (abordees / total).clamp(0.0, 1.0);

  /// Un domaine vide n'est jamais « terminé » : il n'y avait rien à lire.
  bool get termine => total > 0 && abordees >= total;
}

/// L'avancement complet : le pack et chacun de ses domaines.
class AcademyProgress {
  const AcademyProgress({
    required this.abordees,
    required this.total,
    required this.parDomaine,
  });

  final int abordees;
  final int total;

  /// Un domaine absent du pack n'a pas d'entrée : l'écran ne montre que ce
  /// qui existe, comme la barre de domaines le fait déjà.
  final Map<AcademyCategory, DomainProgress> parDomaine;

  /// Domaines entièrement abordés, dans l'ordre du manifeste.
  List<AcademyCategory> get domainesTermines => [
    for (final entree in parDomaine.entries)
      if (entree.value.termine) entree.key,
  ];

  /// Domaines qui contiennent au moins une leçon.
  int get domainesServis => parDomaine.length;
}

/// Croise le pack et les réponses déjà données. FONCTION PURE : ni horloge,
/// ni base, ni réseau — elle se teste sans monter un écran.
AcademyProgress computeAcademyProgress({
  required List<Lesson> lessons,
  required Set<String> answeredIds,
}) {
  final parDomaine = <AcademyCategory, DomainProgress>{};
  var abordees = 0;

  for (final category in AcademyCategory.values) {
    final duDomaine = lessons.where((lesson) => lesson.category == category);
    if (duDomaine.isEmpty) {
      continue;
    }
    final repondues = duDomaine
        .where((lesson) => answeredIds.contains(lesson.id))
        .length;
    abordees += repondues;
    parDomaine[category] = DomainProgress(
      abordees: repondues,
      total: duDomaine.length,
    );
  }

  return AcademyProgress(
    abordees: abordees,
    total: lessons.length,
    parDomaine: parDomaine,
  );
}

/// Le domaine que cette réponse vient d'ACHEVER, s'il y en a un.
///
/// Calculé en comparant l'avant et l'après plutôt qu'en regardant l'état
/// final : sans cette comparaison, rouvrir l'écran d'un pack déjà terminé
/// rejouerait la célébration à chaque fois, et une fête qui revient ne
/// célèbre plus rien.
AcademyCategory? domaineAcheve({
  required AcademyProgress avant,
  required AcademyProgress apres,
}) {
  for (final category in apres.parDomaine.keys) {
    final etaitTermine = avant.parDomaine[category]?.termine ?? false;
    if (!etaitTermine && (apres.parDomaine[category]?.termine ?? false)) {
      return category;
    }
  }
  return null;
}
