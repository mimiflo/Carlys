import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/auth/jwt.dart';
import '../../../../core/auth/token_storage.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/auth_session_device.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/social_provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api.dart';
import '../datasources/social_sign_in.dart';
import '../dto/auth_dtos.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._api,
    required this._storage,
    required this._socialSignIn,
  });

  static const _logger = AppLogger('AuthRepository');

  final AuthApi _api;
  final TokenStorage _storage;
  final SocialSignIn _socialSignIn;

  static String get _devicePlatform =>
      Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'desktop');

  @override
  Future<bool> hasStoredSession() => _storage.hasSession;

  /// Le claim `sub` du jeton d'accès : exactement l'identité sous laquelle le
  /// serveur attribuera ce que l'appareil enverra, et lisible sans réseau.
  ///
  /// Aucune vérification de signature ici : le jeton vient du trousseau, on
  /// n'en lit qu'un identifiant pour un rangement local — c'est le serveur
  /// qui le vérifie à l'envoi.
  @override
  Future<String?> currentAccountId() async {
    final token = await _storage.readAccessToken();
    return token == null ? null : jwtSubjectOf(token);
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _openSession(
      () => _api.register(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
        devicePlatform: _devicePlatform,
      ),
    );
  }

  @override
  Future<AuthUser> login({required String email, required String password}) {
    return _openSession(
      () => _api.login(
        email: email.trim(),
        password: password,
        devicePlatform: _devicePlatform,
      ),
    );
  }

  @override
  Future<AuthUser?> signInWithProvider(SocialProvider provider) async {
    // Le SDK d'abord (hors de `_guard` : ses erreurs ne sont pas des erreurs
    // Dio), le serveur ensuite. La personne peut renoncer devant la feuille :
    // c'est un `null`, pas un échec.
    final credential = await _socialSignIn.obtain(provider);
    if (credential == null) return null;

    return _openSession(
      () => _api.socialLogin(
        provider: provider.wireName,
        idToken: credential.idToken,
        displayName: credential.displayName,
        devicePlatform: _devicePlatform,
      ),
    );
  }

  @override
  Future<void> logout() async {
    // Le SDK retient le compte choisi : sans cet oubli, le bouton
    // reconnecterait le même compte sans jamais reproposer le choix.
    try {
      await _socialSignIn.forget();
    } on Exception catch (error) {
      _logger.warning('Oubli du compte social impossible', error: error);
    }
    try {
      await _api.logout();
    } on Exception catch (error) {
      // Hors ligne ou session déjà invalide : la déconnexion locale prime.
      _logger.warning('Révocation serveur impossible', error: error);
    } finally {
      await _storage.clear();
    }
  }

  @override
  Future<void> forgotPassword(String email) {
    return _guard(() => _api.forgotPassword(email.trim()));
  }

  @override
  Future<AuthUser> me() {
    return _guard(() async => (await _api.me()).toEntity());
  }

  @override
  Future<AuthUser> updateTimezone(String timezone) {
    return _guard(() async => (await _api.updateTimezone(timezone)).toEntity());
  }

  @override
  Future<List<AuthSessionDevice>> sessions() {
    return _guard(() async {
      final sessions = await _api.sessions();
      return sessions.map((dto) => dto.toEntity()).toList();
    });
  }

  @override
  Future<void> revokeSession(String sessionId) {
    return _guard(() => _api.revokeSession(sessionId));
  }

  @override
  Future<void> revokeOtherSessions() {
    return _guard(() => _api.revokeOtherSessions());
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    // Les mots de passe ne sont NI trimés NI normalisés : un espace final
    // fait partie du secret, le retirer changerait ce que l'utilisateur a
    // tapé et ferait échouer la vérification côté serveur.
    return _guard(
      () => _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }

  @override
  Future<void> deleteAccount(String password) {
    return _guard(() => _api.deleteAccount(password));
  }

  @override
  Future<void> clearLocalSession() async {
    // Appelé après une suppression de compte : le SDK retient encore le
    // compte choisi, et le bouton suivant reconnecterait sans reproposer le
    // choix — sur l'ancien compte, désormais supprimé, ou sur celui du
    // propriétaire précédent d'un appareil partagé.
    try {
      await _socialSignIn.forget();
    } on Exception catch (error) {
      _logger.warning('Oubli du compte social impossible', error: error);
    }
    await _storage.clear();
  }

  @override
  Future<void> resendEmailVerification() {
    return _guard(() => _api.resendEmailVerification());
  }

  /// Ouvre une session : l'appel, la LECTURE de la réponse, puis
  /// l'enregistrement des jetons. Trois échecs possibles, trois types
  /// distincts — un `TypeError` de désérialisation ou une erreur du
  /// trousseau traversaient jusqu'ici l'écran sous une forme anonyme, et
  /// rien ne disait lequel des deux avait joué.
  ///
  /// L'appel échoue en [AppException] par `_guard` ; une réponse 2xx
  /// illisible, en [MalformedResponseException], nommée par `AuthApi`, là où
  /// la réponse et son identifiant de requête sont encore sous la main — y
  /// compris quand Dio lui-même n'a pas pu la décoder (`mapDioException`) ;
  /// le trousseau qui refuse, en [StorageException] par [_keep].
  Future<AuthUser> _openSession(
    Future<AuthResultDto> Function() request,
  ) async {
    final result = await _guard(request);
    final user = result.user.toEntity();
    await _keep(result.tokens);
    return user;
  }

  /// Enregistre les jetons reçus, ou renonce à la session.
  ///
  /// Le serveur vient d'ouvrir une session que l'appareil ne sait pas
  /// garder : la laisser vivre là-bas, c'est une ligne de plus dans
  /// « Appareils connectés » que personne ne pourra jamais fermer d'ici ; et
  /// garder en mémoire un jeton que le trousseau n'a pas pris, c'est une
  /// session à moitié ouverte. On la révoque (au mieux) et on vide tout.
  Future<void> _keep(AuthTokensDto tokens) async {
    try {
      await _storage.save(
        StoredTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        ),
      );
    } catch (error, trace) {
      // `catch` NU : le trousseau refuse par une `PlatformException` comme
      // par une `Error` (keystore en vrac, matériel verrouillé).
      await _abandon();
      throw StorageException(
        'Jetons de session non enregistrés',
        cause: error,
        stackTrace: trace,
      );
    }
  }

  /// [logout], sans jamais jeter : il sert après un échec, qu'il ne doit
  /// pas masquer.
  Future<void> _abandon() async {
    try {
      await logout();
    } catch (error) {
      _logger.warning('Session abandonnée incomplètement', error: error);
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    api: AuthApi(ref.watch(dioProvider)),
    storage: ref.watch(tokenStorageProvider),
    socialSignIn: ref.watch(socialSignInProvider),
  );
});
