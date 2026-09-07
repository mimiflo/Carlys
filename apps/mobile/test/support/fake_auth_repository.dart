import 'dart:async';

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

  /// Fuseaux reçus par `updateTimezone`, dans l'ordre.
  final List<String> timezonesSent = <String>[];

  /// Panne à faire subir à la déclaration de fuseau. `Object?`, et non
  /// `AppException?` : le dépôt ne convertit que les `DioException`, donc une
  /// enveloppe inattendue remonte en `FormatException` brute — le cas qui
  /// s'échappait d'un `on AppException`.
  Object? timezoneFailure;

  /// Retient la RÉPONSE de `updateTimezone` jusqu'à ce que le test la
  /// libère. C'est ce laps de temps, sur un vrai réseau, pendant lequel la
  /// session peut se fermer ou l'appareil changer de compte : sans un moyen
  /// de le reproduire, aucun test ne peut exercer la garde qui défend cette
  /// frontière. Null = la réponse revient tout de suite.
  Completer<void>? timezoneGate;

  /// Appels à `clearLocalSession` : c'est la seule preuve que le trousseau a
  /// bien été vidé — `storedSession` seul ne dit pas QUI l'a mis à `false`.
  int clearLocalSessionCalls = 0;

  /// Panne du trousseau (matériel verrouillé, keystore en vrac) : le vrai
  /// `clearLocalSession` va jusqu'au stockage sécurisé, qui peut refuser.
  Object? clearLocalSessionFailure;

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
  Future<AuthUser> updateTimezone(String timezone) async {
    timezonesSent.add(timezone);
    // La réponse du serveur décrit le compte qui a FAIT l'appel, pas celui
    // qui sera connecté quand elle arrivera : on fige l'utilisateur ici.
    final owner = user;
    await timezoneGate?.future;
    final failure = timezoneFailure;
    if (failure != null) throw failure;
    final updated = AuthUser(
      id: owner.id,
      email: owner.email,
      displayName: owner.displayName,
      emailVerified: owner.emailVerified,
      locale: owner.locale,
      timezone: timezone,
      carlysProfile: owner.carlysProfile,
    );
    if (user.id == owner.id) user = updated;
    return updated;
  }

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
    // Le serveur supprime les sessions ; il ne touche PAS au trousseau de
    // l'appareil. Le faux ne doit donc pas le vider non plus, sinon
    // `storedSession` passerait à `false` même si `clearLocalSession`
    // n'était jamais appelé, et l'assertion qui le vérifie ne prouverait
    // plus rien.
    devices = const [];
  }

  @override
  Future<void> clearLocalSession() async {
    clearLocalSessionCalls++;
    final failure = clearLocalSessionFailure;
    if (failure != null) throw failure;
    storedSession = false;
  }

  @override
  Future<void> resendEmailVerification() async {
    resendVerificationCalls++;
    final failure = accountFailure;
    if (failure != null) throw failure;
  }
}
