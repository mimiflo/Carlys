import '../entities/auth_session_device.dart';
import '../entities/auth_user.dart';

/// Contrat du domaine authentification.
///
/// Les implémentations persistent les jetons dans le stockage sécurisé ;
/// les erreurs remontent en AppException, jamais en DioException.
abstract interface class AuthRepository {
  /// Vraie si un refresh token est présent localement.
  Future<bool> hasStoredSession();

  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthUser> login({required String email, required String password});

  /// Révoque la session côté serveur (au mieux) puis efface les jetons locaux.
  Future<void> logout();

  Future<void> forgotPassword(String email);

  Future<AuthUser> me();

  Future<List<AuthSessionDevice>> sessions();

  Future<void> revokeSession(String sessionId);

  Future<void> revokeOtherSessions();
}
