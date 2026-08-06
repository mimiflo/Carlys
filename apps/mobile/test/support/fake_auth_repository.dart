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
  FakeAuthRepository({this.storedSession = false});

  bool storedSession;
  bool failLogin = false;
  int loginCalls = 0;
  int logoutCalls = 0;
  List<AuthSessionDevice> devices = const [];

  @override
  Future<bool> hasStoredSession() async => storedSession;

  @override
  Future<AuthUser> login({required String email, required String password}) async {
    loginCalls++;
    if (failLogin) {
      throw const UnauthorizedException('E-mail ou mot de passe incorrect.');
    }
    storedSession = true;
    return fakeUser;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    storedSession = true;
    return fakeUser;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    storedSession = false;
  }

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<AuthUser> me() async => fakeUser;

  @override
  Future<List<AuthSessionDevice>> sessions() async => devices;

  @override
  Future<void> revokeSession(String sessionId) async {
    devices = devices.where((device) => device.id != sessionId).toList();
  }

  @override
  Future<void> revokeOtherSessions() async {
    devices = devices.where((device) => device.current).toList();
  }
}
