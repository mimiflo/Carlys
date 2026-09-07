/// Compte de démonstration : session toujours ouverte, appareils en mémoire,
/// profil Carlys modifiable (flavor `demo` uniquement) — aucun réseau.
library;

import '../features/authentication/domain/entities/auth_session_device.dart';
import '../features/authentication/domain/entities/auth_user.dart';
import '../features/authentication/domain/repositories/auth_repository.dart';
import '../features/carlys_profile/domain/entities/carlys_profile.dart';
import '../features/carlys_profile/domain/repositories/carlys_profile_repository.dart';
import 'demo_data.dart';

/// Session toujours ouverte ; la connexion accepte n'importe quels
/// identifiants pour laisser explorer les écrans d'authentification.
class DemoAuthRepository implements AuthRepository {
  bool _connected = true;

  /// Le choix de profil Carlys vit ici, comme il vivrait sur le serveur :
  /// `me()` le reflète, donc le rafraîchissement du profil suffit à l'UI —
  /// exactement le flux de production.
  CarlysProfile? _carlysProfile = demoUser.carlysProfile;

  AuthUser get _user => AuthUser(
    id: demoUser.id,
    email: demoUser.email,
    displayName: demoUser.displayName,
    emailVerified: demoUser.emailVerified,
    locale: demoUser.locale,
    timezone: demoUser.timezone,
    carlysProfile: _carlysProfile,
  );

  void chooseCarlysProfile(CarlysProfile profile) {
    _carlysProfile = profile;
  }

  List<AuthSessionDevice> _devices = [
    AuthSessionDevice(
      id: 'demo-device-1',
      current: true,
      createdAt: DateTime.utc(2026, 7, 1),
      lastUsedAt: DateTime.utc(2026, 8, 7),
      deviceName: 'Cet appareil',
      devicePlatform: 'android',
    ),
    AuthSessionDevice(
      id: 'demo-device-2',
      current: false,
      createdAt: DateTime.utc(2026, 6, 15),
      lastUsedAt: DateTime.utc(2026, 8, 2),
      deviceName: 'Tablette du salon',
      devicePlatform: 'android',
    ),
  ];

  @override
  Future<bool> hasStoredSession() async => _connected;

  @override
  Future<String?> currentAccountId() async => _connected ? demoUser.id : null;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    _connected = true;
    return _user;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _connected = true;
    return _user;
  }

  @override
  Future<void> logout() async => _connected = false;

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<AuthUser> me() async => _user;

  @override
  Future<AuthUser> updateTimezone(String timezone) async {
    // La démo n'a pas de serveur à informer : le fuseau reste celui du
    // personnage de démonstration, et l'écran ne montre rien de différent.
    return _user;
  }

  @override
  Future<List<AuthSessionDevice>> sessions() async => _devices;

  @override
  Future<void> revokeSession(String sessionId) async {
    _devices = _devices.where((device) => device.id != sessionId).toList();
  }

  @override
  Future<void> revokeOtherSessions() async {
    _devices = _devices.where((device) => device.current).toList();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Comme sur le serveur : les autres appareils tombent.
    _devices = _devices.where((device) => device.current).toList();
  }

  @override
  Future<void> deleteAccount(String password) async {
    // La démo montre le parcours entier, jusqu'au retour à la connexion :
    // elle n'a pas de compte à détruire, seulement une session à fermer.
    _connected = false;
    _devices = const [];
  }

  @override
  Future<void> clearLocalSession() async => _connected = false;

  @override
  Future<void> resendEmailVerification() async {}
}

/// Choix du profil Carlys en mémoire : écrit chez [DemoAuthRepository], que
/// `me()` reflète — le rafraîchissement du profil suffit, comme en ligne.
class DemoCarlysProfileRepository implements CarlysProfileRepository {
  DemoCarlysProfileRepository(this._auth);

  final DemoAuthRepository _auth;

  @override
  Future<void> choose(CarlysProfile profile) async =>
      _auth.chooseCarlysProfile(profile);
}
