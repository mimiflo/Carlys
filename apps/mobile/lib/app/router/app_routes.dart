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
  static const String history = '/history';
  static const String sessions = '/sessions';
  static const String subscription = '/subscription';
  static const String settings = '/settings';

  static String exerciseDetail(String idOrSlug) => '/exercises/$idOrSlug';

  static String workoutDetail(String sessionId) => '/history/$sessionId';
}
