/// Chemins de navigation nommés.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String sessions = '/home/sessions';
  static const String exercises = '/home/exercises';
  static const String activeWorkout = '/home/workout';
  static const String history = '/home/history';
  static const String progress = '/home/progress';

  static String exerciseDetail(String idOrSlug) => '/home/exercises/$idOrSlug';

  static String workoutDetail(String sessionId) => '/home/history/$sessionId';
}
