/// Chemins de navigation nommés.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  /// Gestes de compte, joignables une fois connecté depuis les réglages.
  static const String changePassword = '/change-password';
  static const String deleteAccount = '/delete-account';

  // Onglets de la coquille (bottom bar)
  static const String home = '/home';
  static const String exercises = '/exercises';
  static const String coach = '/coach';
  static const String progress = '/progress';
  static const String nutrition = '/nutrition';

  /// Recettes : poussée depuis l'onglet Nutrition, dans sa pile.
  static const String recipes = '/nutrition/recettes';
  static const String profile = '/profile';

  // Plein écran, hors coquille (pas de bottom bar)
  static const String activeWorkout = '/workout';
  static const String templates = '/templates';
  static const String programs = '/programs';

  /// Les entrées de génération de programme (Plan 4) : objectif,
  /// expérience, rythme, matériel — le futur écran de génération.
  static const String programSetup = '/programs/preparation';
  static const String history = '/history';
  static const String sessions = '/sessions';
  static const String subscription = '/subscription';
  static const String settings = '/settings';
  static const String carlysProfiles = '/profil-carlys';

  /// Le profil de progression : cinq axes, des points, un titre.
  static const String progression = '/progression';

  /// Le manifeste de marque, qui explique ces cinq axes.
  static const String manifesto = '/manifeste';
  static const String welcome = '/bienvenue';
  static const String onboarding = '/onboarding';

  /// Les six onglets : réorganisation d'août 2026, plus la nutrition
  /// promue pilier en septembre 2026.
  static const String training = '/training';
  static const String academy = '/academy';
  static const String community = '/community';

  static String exerciseDetail(String idOrSlug) => '/exercises/$idOrSlug';

  /// La courbe de charge d'UN exercice, avec ses records posés dessus.
  ///
  /// Poussée depuis l'onglet Progrès : c'est là qu'on se demande « est-ce
  /// que je progresse sur CE mouvement », question à laquelle le volume
  /// agrégé de la page ne répond pas.
  static String exerciseProgression(String exerciseId) =>
      '$progress/exercises/$exerciseId';

  /// LA FRISE : ce qui s'est passé, dans l'ordre.
  ///
  /// Poussée depuis l'onglet Progrès, qui répond à « où j'en suis » là où
  /// la frise répond à « d'où je viens ».
  static String get timeline => '$progress/timeline';

  /// Bibliothèque ouverte directement sur un groupe musculaire — le pont
  /// « apprendre → pratiquer » des fiches d'anatomie de l'Academy.
  static String exercisesForGroup(String slug) => '/exercises?groupe=$slug';

  /// Le quiz d'un domaine BOUCLÉ de l'Academy : ses questions rejouées
  /// d'un trait. `domaine` est le nom de l'énumération, clé du pack.
  static String academyDomainQuiz(String domaine) => '/academy/quiz/$domaine';

  /// Le Parcours guidé : la vue des six étapes, puis chaque étape.
  static const String academyJourney = '/academy/parcours';
  static String academyJourneyStage(int rang) => '/academy/parcours/$rang';

  static String workoutDetail(String sessionId) => '/history/$sessionId';

  /// Éditeur d'un modèle de séance.
  ///
  /// Il n'existe **pas** de route `/templates/new` : créer un modèle, c'est
  /// générer un UUID côté client puis ouvrir son éditeur. C'est la traduction
  /// directe du principe « identifiants générés hors ligne », et ça évite la
  /// collision de chemins entre `new` et `:templateId`.
  static String templateEditor(String templateId) => '/templates/$templateId';

  /// Comme les modèles : l'identifiant d'un nouveau programme est un UUID
  /// généré sur l'appareil, jamais une route `/programs/new`.
  static String programDetail(String programId) => '/programs/$programId';

  /// Le CALENDRIER DATÉ d'un programme : la grille posée sur de vraies
  /// dates. Sous la fiche du programme, parce qu'il n'existe pas sans elle.
  static String programCalendar(String programId) =>
      '/programs/$programId/calendrier';
}
