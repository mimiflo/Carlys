import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_session_device.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/authentication/domain/repositories/auth_repository.dart';

const fakeUser = AuthUser(
  id: 'user-1',
  email: 'camille@example.com',
  displayName: 'Camille',
  emailVerified: true,
  locale: 'fr',
  timezone: 'Europe/Paris',
);

/// Implémentation de test du contrat AuthRepository.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.storedSession = false, this.user = fakeUser});

  bool storedSession;
  bool failLogin = false;
  int loginCalls = 0;
  int logoutCalls = 0;

  /// Utilisateur rendu par `login`/`register`/`me` — remplaçable pour les
  /// tests qui ont besoin d'un profil Carlys choisi.
  AuthUser user;
  List<AuthSessionDevice> devices = const [];

  /// Panne à faire subir aux appels d'appareils : hors ligne
  /// (`NetworkException`) ou serveur en vrac (`ServerException`). Null =
  /// tout va bien.
  AppException? sessionsFailure;

  /// Erreur rendue par les gestes de compte (mot de passe, suppression) —
  /// mauvais mot de passe, hors ligne. Null = geste accepté.
  AppException? accountFailure;

  int revokeCalls = 0;
  int revokeOtherCalls = 0;
  int resendVerificationCalls = 0;

  /// Couples (ancien, nouveau) reçus par `changePassword`.
  final List<(String, String)> passwordChanges = <(String, String)>[];

  /// Mots de passe reçus par `deleteAccount`.
  final List<String> deletionPasswords = <String>[];

  @override
  Future<bool> hasStoredSession() async => storedSession;

  @override
  Future<String?> currentAccountId() async => storedSession ? user.id : null;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (failLogin) {
      throw const UnauthorizedException('E-mail ou mot de passe incorrect.');
    }
    storedSession = true;
    return user;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    storedSession = true;
    return user;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    storedSession = false;
  }

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<AuthUser> me() async => user;

  @override
  Future<List<AuthSessionDevice>> sessions() async {
    final failure = sessionsFailure;
    if (failure != null) throw failure;
    return devices;
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    revokeCalls++;
    final failure = sessionsFailure;
    if (failure != null) throw failure;
    devices = devices.where((device) => device.id != sessionId).toList();
  }

  @override
  Future<void> revokeOtherSessions() async {
    revokeOtherCalls++;
    final failure = sessionsFailure;
    if (failure != null) throw failure;
    devices = devices.where((device) => device.current).toList();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordChanges.add((currentPassword, newPassword));
    final failure = accountFailure;
    if (failure != null) throw failure;
    // Le serveur révoque les autres sessions : le faux en fait autant, pour
    // que les tests qui regardent la liste voient la même chose.
    devices = devices.where((device) => device.current).toList();
  }

  @override
  Future<void> deleteAccount(String password) async {
    deletionPasswords.add(password);
    final failure = accountFailure;
    if (failure != null) throw failure;
    storedSession = false;
    devices = const [];
  }

  @override
  Future<void> clearLocalSession() async {
    storedSession = false;
  }

  @override
  Future<void> resendEmailVerification() async {
    resendVerificationCalls++;
    final failure = accountFailure;
    if (failure != null) throw failure;
  }
}
