import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../app/environment/app_environment.dart';
import '../../domain/entities/social_provider.dart';

/// Ce que le SDK d'un fournisseur rapporte, et rien de plus.
class SocialCredential {
  const SocialCredential({required this.idToken, this.displayName});

  /// Jeton d'IDENTITÉ signé par le fournisseur. Il ne prouve rien tant que
  /// le SERVEUR ne l'a pas vérifié — c'est lui qui décide, pas l'appareil.
  final String idToken;

  /// Nom transmis par le SDK. Apple ne le donne qu'à la TOUTE PREMIÈRE
  /// connexion et jamais ensuite : il faut le faire suivre au serveur ce
  /// jour-là, ou le perdre pour de bon.
  final String? displayName;
}

/// Pourquoi l'appareil n'a même pas pu DEMANDER de jeton.
enum SocialSignInObstacle {
  /// Le fournisseur ne s'ouvre pas sur cette plateforme (Apple sur Android).
  plateforme,

  /// Le build n'a pas de quoi demander un jeton pour notre serveur
  /// (client OAuth absent), ou le SDK n'en a pas rendu.
  configuration,
}

/// L'appareil ne peut pas obtenir de jeton pour ce fournisseur.
///
/// Porte la RAISON : la présentation en tire un message juste sans avoir à
/// interroger la plateforme elle-même — ce qu'un contrôleur ne doit pas faire,
/// et ce qu'un test ne pourrait pas simuler.
class SocialSignInUnavailable implements Exception {
  const SocialSignInUnavailable(this.provider, this.obstacle);

  final SocialProvider provider;
  final SocialSignInObstacle obstacle;
}

/// Passerelle vers les SDK Apple et Google.
///
/// Isolée derrière un contrat : les tests en substituent une version qui ne
/// touche aucune plateforme, et le reste de l'application ne connaît que
/// « un jeton, ou rien ».
abstract interface class SocialSignIn {
  /// Ouvre la feuille du fournisseur. `null` = la personne a renoncé — ce
  /// n'est pas une erreur, il n'y a rien à lui dire.
  Future<SocialCredential?> obtain(SocialProvider provider);

  /// Oublie le compte retenu par le SDK, pour que la prochaine connexion
  /// repropose le choix. Appelé à la déconnexion.
  Future<void> forget();
}

/// Implémentation réelle, adossée aux deux greffons officiels.
class PlatformSocialSignIn implements SocialSignIn {
  PlatformSocialSignIn({required this.environment, GoogleSignIn? google})
    : _google =
          google ??
          GoogleSignIn(
            scopes: const ['email'],
            // Sans ce client « Web », Google n'émet aucun `idToken` pour
            // notre serveur sur Android : la connexion échouerait en
            // silence, avec un jeton que le serveur refuserait.
            serverClientId: environment.googleServerClientId,
          );

  final AppEnvironment environment;
  final GoogleSignIn _google;

  /// Apple ne s'ouvre que sur les plateformes Apple. Sur Android, le dire
  /// vaut mieux que présenter une feuille qui ne s'affichera pas.
  static bool get _appleDisponible => Platform.isIOS || Platform.isMacOS;

  @override
  Future<SocialCredential?> obtain(SocialProvider provider) {
    return switch (provider) {
      SocialProvider.google => _google2(),
      SocialProvider.apple => _apple(),
    };
  }

  Future<SocialCredential?> _google2() async {
    if (environment.googleServerClientId == null) {
      throw const SocialSignInUnavailable(
        SocialProvider.google,
        SocialSignInObstacle.configuration,
      );
    }
    final compte = await _google.signIn();
    if (compte == null) return null; // renoncé
    final auth = await compte.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      // Réponse incomplète du SDK (configuration OAuth incomplète, le plus
      // souvent) : sans jeton d'identité, il n'y a rien à vérifier.
      throw const SocialSignInUnavailable(
        SocialProvider.google,
        SocialSignInObstacle.configuration,
      );
    }
    return SocialCredential(idToken: idToken, displayName: compte.displayName);
  }

  Future<SocialCredential?> _apple() async {
    if (!_appleDisponible) {
      throw const SocialSignInUnavailable(
        SocialProvider.apple,
        SocialSignInObstacle.plateforme,
      );
    }
    final identifiant = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final idToken = identifiant.identityToken;
    if (idToken == null) {
      throw const SocialSignInUnavailable(
        SocialProvider.apple,
        SocialSignInObstacle.configuration,
      );
    }
    // Apple découpe le nom ; il n'arrive qu'une fois dans la vie du compte.
    final nom = [
      identifiant.givenName,
      identifiant.familyName,
    ].whereType<String>().join(' ').trim();
    return SocialCredential(
      idToken: idToken,
      displayName: nom.isEmpty ? null : nom,
    );
  }

  @override
  Future<void> forget() async {
    // Apple n'a rien à oublier côté application : c'est le réglage système
    // du compte Apple qui fait foi.
    await _google.signOut();
  }
}

/// Surchargé dans les tests par une passerelle sans plateforme.
final socialSignInProvider = Provider<SocialSignIn>((ref) {
  return PlatformSocialSignIn(environment: ref.watch(appEnvironmentProvider));
});
