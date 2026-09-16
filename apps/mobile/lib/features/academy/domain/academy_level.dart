/// Les niveaux de l'Academy : des JALONS de lecture, jamais des grades.
///
/// Cinq seuils ABSOLUS de leçons abordées. Absolus et non proportionnels au
/// pack : un pack qui grandit (il grandit à chaque fournée éditoriale) ne
/// doit JAMAIS rétrograder quelqu'un — un seuil exprimé en pourcentage du
/// total reculerait à chaque ajout de contenu.
///
/// Les niveaux sont un AFFICHAGE, pas des récompenses : le journal des
/// récompenses fête déjà ces mêmes franchissements (« maitrise-5 »,
/// « maitrise-moitie », « maitrise-pack »). Créer une récompense par niveau
/// compterait le même fait deux fois — la règle du journal l'interdit.
library;

/// Un niveau : son rang, son nom, le nombre de leçons qui l'ouvre.
class AcademyLevel {
  const AcademyLevel({
    required this.rang,
    required this.nom,
    required this.seuil,
  });

  final int rang;
  final String nom;

  /// Leçons abordées nécessaires. Strictement croissant dans le barème.
  final int seuil;
}

/// Le barème, du premier pas à la lecture de fond.
///
/// Les noms disent un RAPPORT au contenu, pas une valeur de la personne :
/// « Assiduité » décrit une habitude de lecture, là où « Expert » noterait.
const List<AcademyLevel> academyLevels = [
  AcademyLevel(rang: 1, nom: 'Découverte', seuil: 1),
  AcademyLevel(rang: 2, nom: 'Exploration', seuil: 5),
  AcademyLevel(rang: 3, nom: 'Assiduité', seuil: 12),
  AcademyLevel(rang: 4, nom: 'Profondeur', seuil: 20),
  AcademyLevel(rang: 5, nom: 'Érudition', seuil: 30),
];

/// Le niveau atteint, ou `null` avant la première leçon.
///
/// `null` et non un « niveau 0 » : avant toute lecture, la carte parle
/// d'elle-même (« 0 leçons sur 38 ») et un niveau zéro se lirait comme une
/// note d'échec posée d'office.
AcademyLevel? academyLevelOf(int abordees) {
  AcademyLevel? atteint;
  for (final niveau in academyLevels) {
    if (abordees >= niveau.seuil) {
      atteint = niveau;
    }
  }
  return atteint;
}

/// Le prochain niveau à atteindre, ou `null` au sommet du barème.
AcademyLevel? nextAcademyLevelOf(int abordees) {
  for (final niveau in academyLevels) {
    if (abordees < niveau.seuil) {
      return niveau;
    }
  }
  return null;
}
