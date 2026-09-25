import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/social_provider.dart';
import '../../domain/entities/social_sign_in_unavailable.dart';

/// Ce qu'un échec de connexion sociale DIT à la personne, et ce qu'il laisse
/// au propriétaire pour le diagnostiquer : un code court et stable, et, pour
/// une erreur venue du serveur, la référence de la requête.
///
/// Le code renvoie à la table « Diagnostiquer un échec » de
/// `docs/deployment/connexion-sociale.md`. La liste est FERMÉE : chaque
/// code que [describeSocialFailure] peut rendre y figure, et
/// `social_auth_failure_test.dart` les parcourt tous.
final class SocialAuthFailure {
  const SocialAuthFailure({
    required this.code,
    required this.message,
    this.requestId,
    this.unavailable = false,
    this.severe = true,
  });

  /// `google-12500`, `http-429`, `appli-compte`…
  final String code;

  /// La cause en clair, en français, pour la personne.
  final String message;

  /// Identifiant COMPLET de la requête côté serveur, quand il y en a un :
  /// il part entier dans le journal de l'appareil, seul son début s'affiche.
  final String? requestId;

  /// Le fournisseur n'est pas encore branché (build ou serveur) : ce n'est
  /// pas une panne, la popup garde le ton de marque.
  final bool unavailable;

  /// Journalisé en ERREUR (défaut du build, du serveur, de l'application)
  /// plutôt qu'en avertissement (réseau, limite de débit, refus attendu).
  final bool severe;

  /// Ce qui s'affiche après « réf. » : huit caractères suffisent à
  /// retrouver une ligne de journal, et se recopient sans faute.
  String? get reference {
    final id = requestId;
    if (id == null || id.isEmpty) return null;
    return id.length <= 8 ? id : id.substring(0, 8);
  }

  /// La ligne du code, telle qu'elle s'affiche : « Code : http-500 · réf.
  /// 1a2b3c4d ».
  ///
  /// Deux espaces INSÉCABLES : avant le deux-points (typographie
  /// française) et entre « réf. » et sa valeur. À 320 points, texte agrandi
  /// deux fois, la ligne revient à la ligne — après « · », jamais au milieu
  /// d'une référence qu'il faut recopier d'un seul tenant. Mesuré :
  /// « · réf. 1a2b3c4d » soudé d'un bloc était trop large, et la
  /// référence se coupait en deux.
  ///
  /// Et une coupure POSSIBLE, invisible, après chaque `_` du code. Le
  /// moteur de texte coupe après un tiret, jamais après un souligné : sans
  /// elle, `google-failed_to_recover_auth` ne tenait pas en une ligne de
  /// quatorze signes et se tranchait au caractère, en « failed_to_reco » /
  /// « ver_auth », sans marque, et se recopiait de travers. Invisible à
  /// l'écran comme au lecteur d'écran, qui lit [spokenCodeLine].
  String get codeLine {
    final ref = reference;
    final line = 'Code$_nbsp: ${code.replaceAll('_', '_$_breakHere')}';
    return ref == null ? line : '$line · réf.$_nbsp$ref';
  }

  static const String _nbsp = '\u00A0';

  /// Espace sans chasse (U+200B) : autorise une coupure, ne dessine rien.
  static const String _breakHere = '\u200B';

  /// La même ligne, telle qu'un lecteur d'écran doit la DIRE : les tirets
  /// et soulignés deviennent des pauses (« google failed to recover auth »
  /// et non « google tiret failed souligné to… »), et la référence s'épelle
  /// caractère par caractère, parce qu'elle se recopie ainsi.
  String get spokenCodeLine {
    final words = code.replaceAll(RegExp('[-_]'), ' ');
    final ref = reference;
    return ref == null
        ? 'Code : $words'
        : 'Code : $words, référence ${ref.split('').join(' ')}';
  }
}

/// Classe un échec de connexion sociale : le code, la phrase, la gravité.
///
/// Pure, sans Riverpod ni plateforme : TOUT ce qui peut sortir de
/// `AuthController.signInWithProvider` y passe, de l'erreur du SDK à la
/// réclamation d'appareil refusée, et le filet final garde un code.
SocialAuthFailure describeSocialFailure(SocialProvider provider, Object error) {
  return switch (error) {
    SocialSignInUnavailable() => _sdk(error),
    AccountClaimException() => const SocialAuthFailure(
      code: 'appli-compte',
      message:
          'Ton compte n’a pas pu s’ouvrir sur ce téléphone. Réessaie dans '
          'un instant.',
    ),
    StorageException() => const SocialAuthFailure(
      code: 'appli-stockage',
      message:
          'Ce téléphone n’a pas pu enregistrer ta session. Réessaie dans un '
          'instant.',
    ),
    // La réf., quand l'en-tête de l'API était là : elle dit que c'est bien
    // l'API qui a répondu ; son absence, que c'est autre chose.
    MalformedResponseException(:final requestId) => SocialAuthFailure(
      code: 'appli-reponse',
      requestId: requestId,
      message:
          'La réponse du serveur Carlys n’a pas pu être lue. Réessaie dans '
          'un instant, ou mets l’application à jour.',
    ),
    AppException(transport: final how?) => _transport(how),
    // Hors ligne sans précision : c'est quand même le réseau.
    NetworkException() => _transport(TransportFailure.other),
    AppException(statusCode: final status?) when status > 0 => _http(
      provider,
      error,
      status,
    ),
    _ => SocialAuthFailure(
      code: 'appli-inattendu',
      message:
          'La connexion avec ${provider.label} n’a pas abouti. Réessaie, ou '
          'utilise ton adresse e-mail.',
    ),
  };
}

/// Le SDK n'a rendu aucun jeton : le code vient de la passerelle, qui seule
/// connaît le SDK ; la phrase dépend de la catégorie d'obstacle.
SocialAuthFailure _sdk(SocialSignInUnavailable error) {
  final label = error.provider.label;
  return switch (error.obstacle) {
    SocialSignInObstacle.plateforme => SocialAuthFailure(
      code: error.code,
      message:
          'La connexion avec $label n’existe que sur iPhone et iPad. '
          'Utilise Google ou ton adresse e-mail.',
      unavailable: true,
      severe: false,
    ),
    SocialSignInObstacle.configuration => SocialAuthFailure(
      code: error.code,
      message:
          'La connexion avec $label arrive bientôt. Utilise ton adresse '
          'e-mail en attendant.',
      unavailable: true,
    ),
    // Google a bien répondu — il REFUSE cette installation. Le dire
    // « arrive bientôt » envoyait chercher une variable manquante alors que
    // le build est correct : c'est la console Google Cloud qui ne connaît
    // pas le nom de paquet ou l'empreinte de signature de cet APK.
    SocialSignInObstacle.identiteAppareil => SocialAuthFailure(
      code: error.code,
      message:
          '$label n’a pas reconnu cette version de l’application. Utilise '
          'ton adresse e-mail en attendant.',
    ),
    SocialSignInObstacle.reseau => SocialAuthFailure(
      code: error.code,
      message:
          '$label n’est pas joignable. Vérifie ta connexion, puis réessaie.',
      severe: false,
    ),
    SocialSignInObstacle.echec => SocialAuthFailure(
      code: error.code,
      message:
          '$label n’a pas pu terminer la connexion. Réessaie, ou utilise ton '
          'adresse e-mail.',
    ),
  };
}

/// La requête vers Carlys n'a obtenu aucune réponse.
SocialAuthFailure _transport(TransportFailure how) {
  const injoignable =
      'Le serveur Carlys est injoignable. Vérifie ta connexion, puis '
      'réessaie.';
  return switch (how) {
    TransportFailure.timeout => const SocialAuthFailure(
      code: 'reseau-delai',
      message: injoignable,
      severe: false,
    ),
    TransportFailure.connection => const SocialAuthFailure(
      code: 'reseau-connexion',
      message: injoignable,
      severe: false,
    ),
    // Jamais « accepte le certificat » ni « continue quand même » : les
    // deux gestes sûrs sont une date juste (un certificat se lit au
    // calendrier du téléphone) et un autre réseau (un Wi-Fi public peut
    // intercepter la connexion chiffrée).
    TransportFailure.certificate => const SocialAuthFailure(
      code: 'reseau-certificat',
      message:
          'La connexion sécurisée au serveur Carlys a échoué. Vérifie la '
          'date de ton téléphone, ou essaie un autre réseau.',
    ),
    TransportFailure.other => const SocialAuthFailure(
      code: 'reseau-inconnu',
      message: injoignable,
      severe: false,
    ),
  };
}

/// Le serveur a répondu par une erreur HTTP.
SocialAuthFailure _http(
  SocialProvider provider,
  AppException error,
  int status,
) {
  final code = 'http-$status';
  final requestId = error.requestId;
  return switch (status) {
    // Limite STRICTE des routes d'authentification : dix par minute.
    429 => SocialAuthFailure(
      code: code,
      requestId: requestId,
      message:
          'Trop de tentatives de connexion. Attends une minute, puis '
          'réessaie.',
      severe: false,
    ),
    // Le fournisseur n'est pas configuré sur le serveur. L'API masque le
    // message des 5xx : c'est le STATUT qui porte le sens. Seulement le 503
    // de l'API elle-même (son enveloppe) : celui de nginx, API arrêtée ou
    // en redémarrage, n'annonce rien de tel et tombe dans le cas général.
    503 when error.fromApi => SocialAuthFailure(
      code: code,
      requestId: requestId,
      message:
          'La connexion avec ${provider.label} arrive bientôt. Utilise ton '
          'adresse e-mail en attendant.',
      unavailable: true,
    ),
    // Ces refus portent une phrase écrite POUR la personne (adresse non
    // vérifiée, compte suspendu, identité non confirmée) : c'est elle qu'on
    // lit, à la typographie de l'application près. L'API n'écrit pas
    // toujours l'apostrophe courbe, et un serveur plus ancien que
    // l'application ne l'écrira jamais. Seulement quand l'API a écrit la
    // phrase : la page d'erreur d'un intermédiaire n'a rien à dire à la
    // personne, et son texte technique ne s'affiche pas.
    400 || 401 || 403 || 409 || 422 when error.fromApi => SocialAuthFailure(
      code: code,
      requestId: requestId,
      message: error.message.replaceAll("'", '’'),
      severe: false,
    ),
    _ => SocialAuthFailure(
      code: code,
      requestId: requestId,
      message:
          'Le serveur Carlys n’a pas pu ouvrir ta session. Réessaie dans un '
          'instant.',
    ),
  };
}
