import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/social_provider.dart';
import '../utils/social_auth_failure.dart';
import 'auth_controller.dart';

export '../utils/social_auth_failure.dart' show SocialAuthFailure;

/// Ce qu'il y a à DIRE à la fin d'une tentative de connexion sociale.
sealed class SocialAuthOutcome {
  const SocialAuthOutcome();
}

/// Session ouverte — le routeur prend la suite, il n'y a rien à afficher.
final class SocialAuthSucceeded extends SocialAuthOutcome {
  const SocialAuthSucceeded();
}

/// La personne a refermé la feuille du fournisseur. Pas un échec : muet,
/// et sans code.
final class SocialAuthCancelled extends SocialAuthOutcome {
  const SocialAuthCancelled();
}

/// La tentative n'a pas abouti : la cause en clair, et le code à recopier.
///
/// Un fournisseur pas encore branché (client OAuth absent du build, Apple
/// hors iOS, 503 du serveur) passe aussi par ici, avec
/// [SocialAuthFailure.unavailable] : il se dit honnêtement, jamais comme
/// une panne, mais il porte son code comme le reste — c'est précisément
/// quand « tout est configuré » que le propriétaire en a besoin.
final class SocialAuthFailed extends SocialAuthOutcome {
  const SocialAuthFailed(this.failure);

  final SocialAuthFailure failure;
}

/// Pilote les deux boutons sociaux : un seul fournisseur à la fois, et
/// toujours une issue explicite.
///
/// L'état est le fournisseur EN COURS (`null` au repos) — pas un `AsyncValue` :
/// celui-ci naît en chargement le temps de son propre `build`, et les deux
/// boutons se seraient affichés désactivés à la première image, avant tout
/// geste. Ici, au repos veut dire au repos.
///
/// L'écran ne connaît que [SocialAuthOutcome] : ni Dio, ni SDK, ni code HTTP.
class SocialAuthController extends AutoDisposeNotifier<SocialProvider?> {
  static const _logger = AppLogger('SocialAuth');

  bool _gone = false;

  @override
  SocialProvider? build() {
    _gone = false;
    ref.onDispose(() => _gone = true);
    return null;
  }

  Future<SocialAuthOutcome> signIn(SocialProvider provider) async {
    if (state != null) {
      // Une feuille est déjà ouverte : on n'en empile pas une seconde.
      return const SocialAuthCancelled();
    }
    state = provider;
    try {
      final user = await ref
          .read(authControllerProvider.notifier)
          .signInWithProvider(provider);
      return user == null
          ? const SocialAuthCancelled()
          : const SocialAuthSucceeded();
    } catch (error, trace) {
      // UN SEUL rattrapage, et il attrape TOUT. Ce qui sortirait d'ici
      // partirait dans un `onPressed`, où une exception disparaît sans
      // message ni trace. Le classement — code, phrase, gravité — vit dans
      // une fonction pure : ici, on ne fait que le demander, l'écrire une
      // fois dans le journal, et le rendre à l'écran.
      final failure = describeSocialFailure(provider, error);
      _record(provider, failure, error, trace);
      return SocialAuthFailed(failure);
    } finally {
      // Le contrôleur s'auto-dispose : l'écran a pu être quitté pendant que
      // la feuille du fournisseur était ouverte, et écrire dans un
      // contrôleur mort lèverait.
      if (!_gone) state = null;
    }
  }

  /// Une ligne par échec, avec son code et l'identifiant COMPLET de la
  /// requête. Jamais de jeton ni d'adresse : l'erreur journalisée est
  /// l'exception de l'application ou celle du SDK, qui n'en portent pas.
  void _record(
    SocialProvider provider,
    SocialAuthFailure failure,
    Object error,
    StackTrace trace,
  ) {
    final requestId = failure.requestId;
    final line =
        'Connexion ${provider.label} en échec [${failure.code}]'
        '${requestId == null ? '' : ' requestId=$requestId'}';
    if (failure.severe) {
      _logger.error(line, error: error, stackTrace: trace);
    } else {
      _logger.warning(line, error: error);
    }
  }
}

final socialAuthControllerProvider =
    NotifierProvider.autoDispose<SocialAuthController, SocialProvider?>(
      SocialAuthController.new,
    );
