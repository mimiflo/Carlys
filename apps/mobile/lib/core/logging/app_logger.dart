import 'dart:developer' as developer;

/// Niveaux de journalisation alignés sur `package:logging`.
enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const LogLevel(this.value);

  final int value;
}

/// Logger applicatif minimal, sans dépendance.
///
/// Étape 1 : sortie via dart:developer (visible dans DevTools et la console).
/// Sentry s'y branchera comme destination supplémentaire, sans changer les
/// sites d'appel. Ne jamais journaliser de secret ni de token.
class AppLogger {
  const AppLogger(this.name);

  final String name;

  void debug(String message) => _log(LogLevel.debug, message);

  void info(String message) => _log(LogLevel.info, message);

  void warning(String message, {Object? error}) =>
      _log(LogLevel.warning, message, error: error);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      level: level.value,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
