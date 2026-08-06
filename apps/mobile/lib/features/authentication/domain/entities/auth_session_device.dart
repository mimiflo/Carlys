/// Appareil connecté (session active côté serveur).
class AuthSessionDevice {
  const AuthSessionDevice({
    required this.id,
    required this.current,
    required this.createdAt,
    required this.lastUsedAt,
    this.deviceName,
    this.devicePlatform,
  });

  final String id;

  /// Vraie pour la session de cet appareil.
  final bool current;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final String? deviceName;
  final String? devicePlatform;

  String get label =>
      deviceName ?? devicePlatform ?? 'Appareil inconnu';

  @override
  bool operator ==(Object other) => other is AuthSessionDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
