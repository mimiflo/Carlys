/// Le Parcours : six étapes guidées à travers le pack, du premier geste
/// vers les réglages fins.
///
/// C'est un ORDRE DE LECTURE, pas un verrou : l'onglet « Tous » et les
/// domaines restent librement explorables, et une leçon lue hors parcours
/// compte dans le parcours — la réponse est la même donnée. Le manifeste
/// choisit une TRAVERSÉE généraliste : les fiches d'anatomie (référence à
/// consulter) et les filières spécialisées (Hyrox, running, calisthenics)
/// restent en exploration libre, sinon le parcours imposerait le marathon à
/// qui fait de la musculation.
///
/// Le manifeste ne référence que des identifiants du pack, et un test le
/// vérifie ; si une leçon est un jour retirée du pack, le calcul l'ignore
/// plutôt que de bloquer une étape sur une leçon introuvable.
library;

/// Une étape : son rang d'affichage, son intention, ses leçons DANS L'ORDRE.
class JourneyStage {
  const JourneyStage({
    required this.rang,
    required this.nom,
    required this.description,
    required this.lessonIds,
  });

  final int rang;
  final String nom;
  final String description;
  final List<String> lessonIds;
}

/// Les six étapes, votées au plan produit de septembre 2026 :
/// Débutant → Nutrition → Entraînement → Récupération → Discipline →
/// Optimisation.
const List<JourneyStage> academyJourney = [
  JourneyStage(
    rang: 1,
    nom: 'Débutant',
    description: 'Les fondations : progresser, exécuter, ne pas se blesser.',
    lessonIds: [
      'technique-progression',
      'technique-amplitude',
      'technique-echauffement',
      'technique-repos',
      'blessures-progressivite',
      'mythes-courbatures',
    ],
  ),
  JourneyStage(
    rang: 2,
    nom: 'Nutrition',
    description: 'Le carburant : manger pour soutenir l’effort.',
    lessonIds: [
      'nutrition-calories',
      'nutrition-proteines',
      'nutrition-glucides',
      'nutrition-hydratation',
      'nutrition-autour-seance',
    ],
  ),
  JourneyStage(
    rang: 3,
    nom: 'Entraînement',
    description: 'Élargir : le cardio et la mobilité au service du reste.',
    lessonIds: [
      'cardio-zones',
      'cardio-avant-apres',
      'cardio-dose',
      'mobilite-avant-apres',
      'mobilite-regularite',
    ],
  ),
  JourneyStage(
    rang: 4,
    nom: 'Récupération',
    description: 'Progresser, c’est aussi savoir s’arrêter.',
    lessonIds: [
      'recuperation-sommeil',
      'recuperation-frequence',
      'recuperation-courbatures',
      'recuperation-active',
      'blessures-douleur',
    ],
  ),
  JourneyStage(
    rang: 5,
    nom: 'Discipline',
    description: 'La tête : tenir dans la durée, sans se mentir.',
    lessonIds: [
      'mental-discipline',
      'mental-tout-ou-rien',
      'mental-objectifs',
      'mental-comparaison',
      'mythes-localise',
    ],
  ),
  JourneyStage(
    rang: 6,
    nom: 'Optimisation',
    description: 'Affiner : les réglages qui comptent une fois la base là.',
    lessonIds: [
      'mobilite-intensite',
      'cardio-choix',
      'recuperation-decharge',
      'blessures-technique',
      'blessures-reprise',
      'mythes-transformation',
    ],
  ),
];

/// L'avancement d'une étape : ses leçons abordées, sur celles que le pack
/// sert encore.
class StageProgress {
  const StageProgress({required this.abordees, required this.total});

  final int abordees;
  final int total;

  double get ratio => total == 0 ? 0 : (abordees / total).clamp(0.0, 1.0);

  /// Une étape vidée de ses leçons ne bloque pas : elle compte terminée,
  /// il n'y a plus rien à y lire.
  bool get termine => abordees >= total;
}

/// L'avancement du parcours entier, dérivé des mêmes réponses que le reste
/// de l'Academy : rien à stocker, donc rien à désynchroniser.
class JourneyProgress {
  const JourneyProgress({
    required this.parEtape,
    required this.etapeCourante,
    required this.prochaineLecon,
  });

  /// Aligné sur [academyJourney], même ordre.
  final List<StageProgress> parEtape;

  /// Index (0-based) de la première étape non terminée, `null` quand tout
  /// le parcours est lu : c'est la REPRISE AUTOMATIQUE.
  final int? etapeCourante;

  /// Première leçon non abordée de l'étape courante, `null` à la fin.
  final String? prochaineLecon;

  int get etapesTerminees => parEtape.where((e) => e.termine).length;

  bool get termine => etapeCourante == null;
}

/// FONCTION PURE, comme `computeAcademyProgress` : elle croise le manifeste,
/// le pack servi et les réponses, sans horloge ni stockage.
JourneyProgress computeJourneyProgress({
  required List<JourneyStage> stages,
  required Set<String> packIds,
  required Set<String> answeredIds,
}) {
  final parEtape = <StageProgress>[];
  int? etapeCourante;
  String? prochaineLecon;

  for (var i = 0; i < stages.length; i++) {
    // Une leçon retirée du pack sort du compte : sans ce filtre, l'étape
    // resterait bloquée sur une leçon que plus personne ne peut lire.
    final servies = stages[i].lessonIds
        .where(packIds.contains)
        .toList(growable: false);
    final abordees = servies.where(answeredIds.contains).length;
    final progress = StageProgress(abordees: abordees, total: servies.length);
    parEtape.add(progress);

    if (etapeCourante == null && !progress.termine) {
      etapeCourante = i;
      prochaineLecon = servies
          .where((id) => !answeredIds.contains(id))
          .firstOrNull;
    }
  }

  return JourneyProgress(
    parEtape: parEtape,
    etapeCourante: etapeCourante,
    prochaineLecon: prochaineLecon,
  );
}
