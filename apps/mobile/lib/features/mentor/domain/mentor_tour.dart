/// La VISITE GUIDÉE du Mentor : les grandes pièces de l'application, une
/// par étape, dans un ordre fixe.
///
/// Un manifeste constant, comme le Parcours de l'Academy : l'ordre est un
/// conseil, rien n'est verrouillé, et l'état « déjà vu » est local à
/// l'appareil (préférences) — revoir la visite le remet simplement à zéro.
/// Le manifeste ne connaît AUCUNE route : la présentation fait le pont vers
/// `AppRoutes`, et un test vérifie qu'elle couvre chaque étape.
library;

/// Une étape : où elle emmène (par identifiant), ce qu'elle montre.
class MentorTourStep {
  const MentorTourStep({
    required this.id,
    required this.titre,
    required this.corps,
    required this.libelleAller,
  });

  final String id;
  final String titre;

  /// Deux ou trois phrases, ton neutre : la voix du Mentor teinte ses mots
  /// à lui, pas la description des écrans.
  final String corps;

  /// Le libellé du bouton qui y emmène (« Voir l'Academy »).
  final String libelleAller;
}

/// Les sept étapes, du geste quotidien vers le reste.
const List<MentorTourStep> mentorTour = [
  MentorTourStep(
    id: 'accueil',
    titre: 'L’accueil',
    corps:
        'Ta journée en un écran : ta constance, la séance du jour, la '
        'question du jour et ta forme. Tout le reste part d’ici.',
    libelleAller: 'Rester ici',
  ),
  MentorTourStep(
    id: 'entrainement',
    titre: 'L’entraînement',
    corps:
        'Tes séances, tes modèles et tes programmes. Tu peux démarrer une '
        'séance vide ou suivre un modèle : tout se note, même hors ligne.',
    libelleAller: 'Voir l’entraînement',
  ),
  MentorTourStep(
    id: 'nutrition',
    titre: 'La nutrition',
    corps:
        'Ton plan (calories, protéines, eau), ton journal des repas et des '
        'recettes adaptées à ton profil. Chaque chiffre s’explique d’un '
        'geste.',
    libelleAller: 'Voir la nutrition',
  ),
  MentorTourStep(
    id: 'progres',
    titre: 'Les progrès',
    corps:
        'Ton poids, tes mesures, tes records et la courbe de chaque '
        'exercice. Tout se corrige, rien ne se fige.',
    libelleAller: 'Voir les progrès',
  ),
  MentorTourStep(
    id: 'academy',
    titre: 'L’Academy',
    corps:
        'Comprendre ce que tu pratiques : des leçons courtes par domaine, '
        'un parcours guidé en six étapes, et un quiz par domaine bouclé.',
    libelleAller: 'Voir l’Academy',
  ),
  MentorTourStep(
    id: 'communaute',
    titre: 'La communauté',
    corps:
        'Tes amis, leurs encouragements et des défis collectifs. Ta '
        'progression ne se partage que si tu le décides.',
    libelleAller: 'Voir la communauté',
  ),
  MentorTourStep(
    id: 'coach',
    titre: 'Le coach IA',
    corps:
        'Il lit tes vraies données (séances, records, journal) avant de '
        'répondre, et te propose des séances adaptées. C’est lui qui porte '
        'la voix que tu choisis pour ton Mentor.',
    libelleAller: 'Voir le coach',
  ),
];

/// L'avancement de la visite, dérivé du manifeste et des étapes vues.
class MentorTourProgress {
  const MentorTourProgress({required this.vues, required this.prochaine});

  final int vues;

  /// Première étape non vue dans l'ordre du manifeste, `null` quand la
  /// visite est terminée.
  final MentorTourStep? prochaine;

  int get total => mentorTour.length;

  bool get terminee => prochaine == null;
}

/// FONCTION PURE : manifeste + identifiants vus → où en est la visite.
/// Un identifiant inconnu (étape retirée un jour) est ignoré plutôt que
/// compté : la visite se juge sur ce qui se visite encore.
MentorTourProgress computeMentorTour(Set<String> vues) {
  final connus = mentorTour.where((step) => vues.contains(step.id)).length;
  final prochaine = mentorTour
      .where((step) => !vues.contains(step.id))
      .firstOrNull;
  return MentorTourProgress(vues: connus, prochaine: prochaine);
}
