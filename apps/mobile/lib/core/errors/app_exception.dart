/// Hiérarchie d'erreurs applicatives.
///
/// Le domaine et la présentation manipulent ces types — jamais les exceptions
/// brutes de Dio, Drift ou de la plateforme, qui sont converties au niveau
/// des repositories.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  /// Message technique, destiné aux logs — la présentation choisit le texte
  /// utilisateur localisé.
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// Impossible de joindre le serveur (hors ligne, DNS, timeout réseau).
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.stackTrace});
}

/// Le serveur a répondu avec une erreur (5xx, contrat invalide…).
final class ServerException extends AppException {
  const ServerException(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

/// Données locales invalides ou base locale inaccessible.
final class StorageException extends AppException {
  const StorageException(super.message, {super.cause, super.stackTrace});
}

/// Session expirée ou identifiants invalides.
final class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.cause, super.stackTrace});
}

/// Accès refusé par le serveur (ex. contenu réservé aux membres Premium —
/// les droits sont TOUJOURS décidés côté serveur).
final class ForbiddenException extends AppException {
  const ForbiddenException(super.message, {super.cause, super.stackTrace});
}

/// Données saisies invalides (validation serveur ou locale).
final class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });

  /// Erreurs par champ, ex. {'email': 'Adresse invalide'}.
  final Map<String, String> fieldErrors;
}

/// Erreur inattendue, non classifiée.
final class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause, super.stackTrace});
}
