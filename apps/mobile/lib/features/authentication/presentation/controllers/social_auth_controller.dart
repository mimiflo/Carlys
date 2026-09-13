import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/datasources/social_sign_in.dart';
import '../../domain/entities/social_provider.dart';
import 'auth_controller.dart';

/// Ce qu'il y a à DIRE à la fin d'une tentative de connexion sociale.
sealed class SocialAuthOutcome {
  const SocialAuthOutcome();
}

/// Session ouverte — le routeur prend la suite, il n'y a rien à afficher.
final class SocialAuthSucceeded extends SocialAuthOutcome {
  const SocialAuthSucceeded();
}

/// La personne a refermé la feuille du fournisseur. Pas un échec : muet.
final class SocialAuthCancelled extends SocialAuthOutcome {
  const SocialAuthCancelled();
}

/// Le fournisseur n'est pas encore branché — côté serveur (503) ou côté
/// application (client OAuth absent, Apple hors iOS). À dire honnêtement,
/// jamais comme une panne.
final class SocialAuthUnavailable extends SocialAuthOutcome {
  const SocialAuthUnavailable(this.provider, {required this.appleHorsIos});

  final SocialProvider provider;

  /// Apple demandé sur un appareil qui ne sait pas l'ouvrir.
  final bool appleHorsIos;

  String get message => appleHorsIos
      ? 'La connexion avec Apple n’existe que sur iPhone et iPad. '
            'Utilise Google ou ton adresse e-mail.'
      : 'La connexion avec ${provider.label} arrive bientôt. '
            'Utilise ton adresse e-mail en attendant.';
}

/// Le fournisseur a bien répondu, mais la connexion a échoué. Le message
/// vient du serveur quand il en donne un (adresse non vérifiée, compte
/// suspendu), sinon d'un repli.
final class SocialAuthFailed extends SocialAuthOutcome {
  const SocialAuthFailed(this.message);

  final String message;
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
    } on SocialSignInUnavailable catch (error) {
      // Côté application : client OAuth absent du build, ou fournisseur qui
      // ne s'ouvre pas sur cette plateforme. La RAISON vient de la
      // passerelle — le contrôleur n'interroge pas la plateforme.
      return SocialAuthUnavailable(
        error.provider,
        appleHorsIos: error.obstacle == SocialSignInObstacle.plateforme,
      );
    } on ServerException catch (error) {
      if (error.statusCode == 503) {
        // Côté serveur : le fournisseur n'est pas configuré. Le message des
        // 5xx est masqué par l'API (aucune fuite d'interne) — c'est le CODE
        // qui porte le sens, et il vaut ici « pas encore activé ».
        return SocialAuthUnavailable(provider, appleHorsIos: false);
      }
      return SocialAuthFailed(_repli(provider));
    } on AppException catch (error) {
      return SocialAuthFailed(
        error is UnauthorizedException || error is ValidationException
            // Ces deux-là portent un message écrit POUR la personne
            // (adresse non vérifiée, compte suspendu).
            ? error.message
            : _repli(provider),
      );
    } finally {
      // Le contrôleur s'auto-dispose : l'écran a pu être quitté pendant que
      // la feuille du fournisseur était ouverte, et écrire dans un
      // contrôleur mort lèverait.
      if (!_gone) state = null;
    }
  }

  String _repli(SocialProvider provider) =>
      'La connexion avec ${provider.label} n’a pas abouti. Réessaie, ou '
      'utilise ton adresse e-mail.';
}

final socialAuthControllerProvider =
    NotifierProvider.autoDispose<SocialAuthController, SocialProvider?>(
      SocialAuthController.new,
    );
