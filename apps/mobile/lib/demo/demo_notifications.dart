/// Notifications de la DÉMONSTRATION (flavor `demo`) — aucun réseau.
library;

import '../features/notifications/domain/repositories/device_token_repository.dart';

/// Notifications de démonstration : les préférences vivent en mémoire.
///
/// Sans elle, l'écran Profil de la démonstration appellerait une API qui
/// n'existe pas — un appel voué à l'échec, et un délai d'attente pour rien.
class DemoDeviceTokenRepository implements DeviceTokenRepository {
  final Map<NotificationCategory, bool> _preferences = {};

  @override
  Future<void> register({
    required String token,
    required DevicePlatform platform,
  }) async {}

  @override
  Future<void> unregister(String token) async {}

  @override
  Future<Map<NotificationCategory, bool>> preferences() async => _preferences;

  @override
  Future<void> setPreference(
    NotificationCategory category, {
    required bool enabled,
  }) async {
    _preferences[category] = enabled;
  }
}
