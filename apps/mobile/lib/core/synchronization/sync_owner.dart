import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/jwt.dart';
import '../auth/token_storage.dart';
import '../logging/app_logger.dart';

export '../auth/jwt.dart' show jwtSubjectOf;

/// Qui est connecté sur cet appareil, du point de vue de la file.
///
/// Chaque opération est écrite sous un propriétaire et n'est drainée que
/// sous lui : c'est ce qui empêche la file d'un compte de partir avec le
/// jeton du suivant. `null` quand personne n'est connecté.
abstract interface class SyncOwnerResolver {
  Future<String?> currentOwnerId();
}

/// Lit le propriétaire dans le jeton d'accès (claim `sub`) : c'est
/// exactement l'identité sous laquelle le serveur attribuera l'opération,
/// et elle est disponible **hors ligne**, sans attendre le profil — une
/// séance commencée dans une cave doit pouvoir être enfilée sans réseau.
///
/// Aucune vérification de signature ici : le jeton vient du trousseau, on
/// n'en lit qu'un identifiant pour un rangement local. C'est le serveur qui
/// le vérifie à l'envoi.
class TokenSyncOwnerResolver implements SyncOwnerResolver {
  const TokenSyncOwnerResolver(this._storage);

  static const _logger = AppLogger('SyncOwner');

  final TokenStorage _storage;

  @override
  Future<String?> currentOwnerId() async {
    final token = await _storage.readAccessToken();
    if (token == null) {
      return null;
    }
    final subject = jwtSubjectOf(token);
    if (subject == null) {
      _logger.warning('Jeton d’accès sans claim sub lisible');
    }
    return subject;
  }
}

final syncOwnerResolverProvider = Provider<SyncOwnerResolver>((ref) {
  return TokenSyncOwnerResolver(ref.watch(tokenStorageProvider));
});
