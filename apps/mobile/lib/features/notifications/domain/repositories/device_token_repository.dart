/// Plateforme telle que l'API la connaît (enum `DevicePlatform` côté serveur).
enum DevicePlatform {
  android('ANDROID'),
  ios('IOS');

  const DevicePlatform(this.wire);

  /// Valeur échangée avec l'API.
  final String wire;
}

/// Familles de notifications réglables séparément. Une bascule unique
/// couperait le lien social en même temps que tout le reste, alors qu'on ne
/// refuse pas les deux pour les mêmes raisons.
///
/// Les TROIS du contrat (`notificationCategorySchema`), et un test le tient :
/// la troisième, les invitations à un défi, manquait. Le serveur la rendait,
/// l'appli la jetait comme venue « d'un serveur plus récent », et personne
/// ne pouvait couper les invitations sans couper tout le reste.
enum NotificationCategory {
  friendRequests('FRIEND_REQUESTS', 'Demandes d’ami'),
  encouragements('ENCOURAGEMENTS', 'Encouragements'),
  challengeInvites('CHALLENGE_INVITES', 'Invitations à un défi');

  const NotificationCategory(this.wire, this.label);

  final String wire;
  final String label;

  static NotificationCategory? fromWire(String value) {
    for (final category in NotificationCategory.values) {
      if (category.wire == value) return category;
    }
    // Une catégorie inconnue vient d'un serveur plus récent : on l'ignore
    // plutôt que de faire échouer l'écran des réglages.
    return null;
  }
}

/// Enregistrement des jetons push auprès du serveur.
abstract class DeviceTokenRepository {
  /// Idempotent : rejouer l'enregistrement (ou changer de compte sur le même
  /// appareil) ne crée jamais de doublon — le serveur réaffecte le jeton.
  Future<void> register({
    required String token,
    required DevicePlatform platform,
  });

  /// Oubli à la déconnexion — idempotent lui aussi.
  Future<void> unregister(String token);

  /// Ce que la personne accepte de recevoir. Les catégories jamais réglées
  /// reviennent à `true` : le serveur les rend toutes.
  Future<Map<NotificationCategory, bool>> preferences();

  /// Accepte ou refuse une famille. Le refus est appliqué CÔTÉ SERVEUR, à
  /// l'envoi : une préférence locale laisserait la notification arriver.
  Future<void> setPreference(
    NotificationCategory category, {
    required bool enabled,
  });
}
