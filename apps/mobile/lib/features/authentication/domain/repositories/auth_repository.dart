import '../entities/auth_session_device.dart';
import '../entities/auth_user.dart';

/// Contrat du domaine authentification.
///
/// Les implémentations persistent les jetons dans le stockage sécurisé ;
/// les erreurs remontent en AppException, jamais en DioException.
abstract interface class AuthRepository {
  /// Vraie si un refresh token est présent localement.
  Future<bool> hasStoredSession();

  /// Identifiant du compte dont l'appareil porte la session, `null` si
  /// personne n'est connecté ou si la session est illisible.
  ///
  /// Répondu HORS LIGNE, sans appeler le serveur : c'est ce qui permet de
  /// savoir, dès le démarrage et sans réseau, à qui appartiennent les
  /// données locales (`LocalAccountSwitch`).
  Future<String?> currentAccountId();

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

  /// Change le mot de passe du compte connecté. Le serveur révoque au passage
  /// TOUTES les autres sessions : c'est le geste qui reprend la main sur un
  /// appareil perdu, et l'écran doit le dire avant.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Supprime le compte, mot de passe à l'appui. Irréversible côté serveur :
  /// l'appelant enchaîne sur la purge locale puis l'écran de connexion.
  Future<void> deleteAccount(String password);

  /// Efface les jetons de l'appareil SANS rien demander au serveur — pour le
  /// cas où la session n'existe déjà plus là-bas (compte supprimé). `logout`
  /// ferait un aller-retour condamné au 401 et journaliserait un échec qui
  /// n'en est pas un.
  Future<void> clearLocalSession();

  /// Redemande l'e-mail de vérification d'adresse. Sans effet si l'adresse
  /// est déjà vérifiée — le serveur répond 204 dans les deux cas.
  Future<void> resendEmailVerification();
}
