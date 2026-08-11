/// Plateforme telle que l'API la connaît (enum `DevicePlatform` côté serveur).
enum DevicePlatform {
  android('ANDROID'),
  ios('IOS');

  const DevicePlatform(this.wire);

  /// Valeur échangée avec l'API.
  final String wire;
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
}
