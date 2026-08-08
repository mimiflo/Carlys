/// Chemins de navigation nommés.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Onglets de la coquille (bottom bar)
  static const String home = '/home';
  static const String exercises = '/exercises';
  static const String progress = '/progress';
  static const String nutrition = '/nutrition';
  static const String profile = '/profile';

  // Plein écran, hors coquille (pas de bottom bar)
  static const String activeWorkout = '/workout';
  static const String templates = '/templates';
  static const String history = '/history';
  static const String sessions = '/sessions';
  static const String subscription = '/subscription';
  static const String settings = '/settings';
  static const String welcome = '/bienvenue';
  static const String onboarding = '/onboarding';

  static String exerciseDetail(String idOrSlug) => '/exercises/$idOrSlug';

  static String workoutDetail(String sessionId) => '/history/$sessionId';

  /// Éditeur d'un modèle de séance.
  ///
  /// Il n'existe **pas** de route `/templates/new` : créer un modèle, c'est
  /// générer un UUID côté client puis ouvrir son éditeur. C'est la traduction
  /// directe du principe « identifiants générés hors ligne », et ça évite la
  /// collision de chemins entre `new` et `:templateId`.
  static String templateEditor(String templateId) => '/templates/$templateId';
}
