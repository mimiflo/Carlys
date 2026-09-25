/// Hiérarchie d'erreurs applicatives.
///
/// Le domaine et la présentation manipulent ces types — jamais les exceptions
/// brutes de Dio, Drift ou de la plateforme, qui sont converties au niveau
/// des repositories.
sealed class AppException implements Exception {
  const AppException(
    this.message, {
    this.cause,
    this.stackTrace,
    this.statusCode,
    this.requestId,
    this.transport,
    this.fromApi = false,
  });

  /// Message technique, destiné aux logs — la présentation choisit le texte
  /// utilisateur localisé.
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  /// Statut HTTP de la réponse d'erreur, quand le serveur en a rendu une.
  ///
  /// Posé par `mapDioException` sur TOUTE la hiérarchie, pas seulement sur
  /// [ServerException] : un 401 et un 403 se diagnostiquent aussi, même
  /// quand le texte affiché n'en dépend pas.
  final int? statusCode;

  /// Identifiant de la requête côté serveur : celui de l'enveloppe d'erreur,
  /// à défaut celui de l'en-tête `x-request-id` (y compris d'une réponse 2xx
  /// illisible, [MalformedResponseException]). C'est lui qui retrouve LA
  /// ligne de journal du serveur. Jamais un secret : le serveur le renvoie
  /// à n'importe quel appelant.
  final String? requestId;

  /// Comment la requête a échoué SANS réponse HTTP (délai, connexion,
  /// certificat). `null` dès que le serveur a répondu.
  final TransportFailure? transport;

  /// La réponse d'erreur portait l'ENVELOPPE de l'API Carlys : [message]
  /// est alors une phrase écrite par l'API, et le statut dit ce que l'API a
  /// décidé. Faux pour la page d'erreur d'un intermédiaire (nginx quand
  /// l'API est arrêtée, portail captif, proxy d'entreprise) : son 503 ne
  /// veut pas dire « pas encore activé », et son texte ne s'affiche pas.
  final bool fromApi;

  @override
  String toString() => '$runtimeType: $message';
}

/// Pourquoi une requête n'a obtenu AUCUNE réponse. Sert au diagnostic : le
/// type d'exception, lui, continue de dire « hors ligne » ou « inattendu ».
enum TransportFailure {
  /// Délai dépassé (connexion, envoi, réception).
  timeout,

  /// Connexion refusée ou coupée, adresse introuvable.
  connection,

  /// Certificat refusé, ou poignée de main TLS en échec.
  certificate,

  /// Requête annulée, ou échec que Dio ne classe pas.
  other,
}

/// Impossible de joindre le serveur (hors ligne, DNS, timeout réseau).
final class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.transport,
  });
}

/// Le serveur a répondu avec une erreur (5xx, 404, 429…).
final class ServerException extends AppException {
  const ServerException(
    super.message, {
    super.statusCode,
    super.requestId,
    super.fromApi,
    super.cause,
    super.stackTrace,
  });
}

/// Le serveur a répondu SANS erreur, mais sa réponse ne se lit pas : corps
/// qui n'est pas un objet JSON (page HTML d'un portail, liste, JSON
/// tronqué), enveloppe manquante, champ absent ou d'un autre type. Un défaut
/// de CONTRAT entre l'application et ce qui a répondu, pas une panne — ni
/// du réseau, ni du serveur.
///
/// [requestId] n'est posé que si la réponse portait l'en-tête de l'API :
/// avec lui, c'est bien l'API Carlys qui a répondu ; sans lui, c'est
/// souvent autre chose (portail captif, adresse d'API qui pointe ailleurs).
final class MalformedResponseException extends AppException {
  const MalformedResponseException(
    super.message, {
    super.requestId,
    super.cause,
    super.stackTrace,
  });
}

/// Données locales invalides ou base locale inaccessible — y compris le
/// trousseau qui refuse d'enregistrer les jetons d'une session.
final class StorageException extends AppException {
  const StorageException(super.message, {super.cause, super.stackTrace});
}

/// L'appareil n'a pas pu être rendu au compte qui arrive : la purge des
/// données du compte précédent, ou l'écriture du nouveau propriétaire, a
/// échoué (`LocalAccountSwitch.claimDevice`). La session n'est PAS ouverte :
/// l'ouvrir quand même, ce serait montrer à ce compte les données d'un autre.
final class AccountClaimException extends AppException {
  const AccountClaimException(super.message, {super.cause, super.stackTrace});
}

/// Session expirée ou identifiants invalides.
final class UnauthorizedException extends AppException {
  const UnauthorizedException(
    super.message, {
    super.statusCode,
    super.requestId,
    super.fromApi,
    super.cause,
    super.stackTrace,
  });
}

/// Accès refusé par le serveur (ex. contenu réservé aux membres Premium —
/// les droits sont TOUJOURS décidés côté serveur).
final class ForbiddenException extends AppException {
  const ForbiddenException(
    super.message, {
    super.statusCode,
    super.requestId,
    super.fromApi,
    super.cause,
    super.stackTrace,
  });
}

/// Données saisies invalides (validation serveur ou locale).
final class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
    super.statusCode,
    super.requestId,
    super.fromApi,
    super.cause,
    super.stackTrace,
  });

  /// Erreurs par champ, ex. {'email': 'Adresse invalide'}.
  final Map<String, String> fieldErrors;
}

/// Erreur inattendue, non classifiée.
final class UnknownException extends AppException {
  const UnknownException(
    super.message, {
    super.cause,
    super.stackTrace,
    super.transport,
  });
}
