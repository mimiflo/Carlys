import 'dart:io' show Platform;

import 'package:flutter/services.dart' show PlatformException;
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

  /// Le fournisseur REFUSE cette installation : côté Google, le nom de
  /// paquet ou l'empreinte SHA-1 de la clé de signature ne figurent pas
  /// dans le client OAuth Android (`ApiException: 10`, DEVELOPER_ERROR).
  ///
  /// Distingué de [configuration] parce que le geste correctif n'est pas le
  /// même : ici le build est bon, c'est la console Google Cloud qui ne
  /// connaît pas cet APK. Les confondre envoyait chercher une variable
  /// manquante là où tout était correctement injecté.
  identiteAppareil,
}

/// L'appareil ne peut pas obtenir de jeton pour ce fournisseur.
///
/// Porte la RAISON : la présentation en tire un message juste sans avoir à
/// interroger la plateforme elle-même — ce qu'un contrôleur ne doit pas faire,
/// et ce qu'un test ne pourrait pas simuler.
class SocialSignInUnavailable implements Exception {
  const SocialSignInUnavailable(this.provider, this.obstacle, {this.cause});

  final SocialProvider provider;
  final SocialSignInObstacle obstacle;

  /// L'erreur d'origine du SDK — pour les logs, jamais pour l'affichage.
  final Object? cause;

  @override
  String toString() =>
      'SocialSignInUnavailable(${provider.name}, ${obstacle.name}, $cause)';
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
            // Client OAuth *iOS*, et seulement là : Android identifie
            // l'application par son nom de paquet et l'empreinte de sa clé,
            // pas par un identifiant embarqué — le greffon Android ignore
            // celui-ci, autant ne pas le lui passer.
            clientId: Platform.isIOS || Platform.isMacOS
                ? environment.googleIosClientId
                : null,
          );

  final AppEnvironment environment;
  final GoogleSignIn _google;

  /// Apple ne s'ouvre que sur les plateformes Apple. Sur Android, le dire
  /// vaut mieux que présenter une feuille qui ne s'affichera pas.
  static bool get _appleDisponible => Platform.isIOS || Platform.isMacOS;

  @override
  Future<SocialCredential?> obtain(SocialProvider provider) {
    return switch (provider) {
      SocialProvider.google => _googleSignIn(),
      SocialProvider.apple => _apple(),
    };
  }

  /// Statut `DEVELOPER_ERROR` des services Google Play, tel qu'il arrive
  /// enveloppé dans le message d'une `PlatformException` :
  /// « com.google.android.gms.common.api.ApiException: 10: ». Le `\b` évite
  /// de confondre 10 avec 100 (`DEVELOPER_ERROR` contre un statut inconnu).
  static final RegExp _erreurDeveloppeur = RegExp(r':\s*10\b');

  /// Traduit l'échec du SDK Google en obstacle NOMMÉ.
  ///
  /// `sign_in_failed` recouvre plusieurs causes très différentes ; seule
  /// celle qui porte le statut 10 signifie « Google ne reconnaît pas cette
  /// installation ». Les autres restent une configuration incomplète.
  static SocialSignInObstacle _obstacleGoogle(PlatformException error) {
    final estRefusDIdentite =
        error.code == 'sign_in_failed' &&
        _erreurDeveloppeur.hasMatch(error.message ?? '');
    return estRefusDIdentite
        ? SocialSignInObstacle.identiteAppareil
        : SocialSignInObstacle.configuration;
  }

  Future<SocialCredential?> _googleSignIn() async {
    if (environment.googleServerClientId == null) {
      throw const SocialSignInUnavailable(
        SocialProvider.google,
        SocialSignInObstacle.configuration,
      );
    }
    // iOS n'a pas d'équivalent au couple « nom de paquet + empreinte » :
    // le SDK y exige un client OAuth iOS, passé en `clientId` ou posé en
    // `GIDClientID` dans l'Info.plist. Sans lui, le greffon lève au premier
    // appel. Le dire ici vaut mieux que laisser planter la feuille.
    if (Platform.isIOS && environment.googleIosClientId == null) {
      throw const SocialSignInUnavailable(
        SocialProvider.google,
        SocialSignInObstacle.configuration,
      );
    }
    final GoogleSignInAccount? compte;
    final GoogleSignInAuthentication auth;
    try {
      // Oublier le compte AVANT de demander, et non seulement à la
      // déconnexion. Raison mécanique, lisible dans le greffon lui-même
      // (google_sign_in 6.3.0, lib/google_sign_in.dart:100-102) :
      //
      //   // On Android, there isn't an API for refreshing the idToken, so
      //   // re-use the one we obtained on login.
      //   response.idToken ??= _idToken;
      //
      // Le jeton d'identité n'est JAMAIS régénéré sur Android : c'est celui
      // de la première connexion. Et `signIn()` rend le compte en cache sans
      // rouvrir la feuille. Au deuxième appui, on renvoyait donc un jeton
      // vieilli, que le serveur refuse passé sa fenêtre d'âge : la connexion
      // marchait UNE fois, puis échouait jusqu'au redémarrage de
      // l'application — en affichant une cause fausse. `signOut()` ne touche
      // que le cache local du SDK ; sur un bouton de connexion, rouvrir le
      // choix du compte est de toute façon le geste attendu.
      await _google.signOut();
      compte = await _google.signIn();
      if (compte == null) return null; // renoncé
      // DANS le try : `authentication` lève elle aussi des
      // `PlatformException` (jeton irrécupérable, compte révoqué). Dehors,
      // elles traversaient `obtain()` et rompaient son contrat
      // « un jeton, ou rien ».
      auth = await compte.authentication;
    } on PlatformException catch (error) {
      // Le SDK Google avale l'annulation et rend `null` ; ce qui remonte ici
      // est un vrai échec.
      throw SocialSignInUnavailable(
        SocialProvider.google,
        _obstacleGoogle(error),
        cause: error,
      );
    }
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
    final AuthorizationCredentialAppleID identifiant;
    try {
      identifiant = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      // Apple, CONTRAIREMENT à Google, LÈVE quand on referme la feuille.
      // Sans ce rattrapage, l'exception traversait le contrôleur et
      // ressortait d'un `onPressed` : aucun message, aucune trace, un bouton
      // qui semble ne rien faire.
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw SocialSignInUnavailable(
        SocialProvider.apple,
        SocialSignInObstacle.configuration,
        cause: error,
      );
    } on SignInWithAppleException catch (error) {
      throw SocialSignInUnavailable(
        SocialProvider.apple,
        SocialSignInObstacle.configuration,
        cause: error,
      );
    } on PlatformException catch (error) {
      throw SocialSignInUnavailable(
        SocialProvider.apple,
        SocialSignInObstacle.configuration,
        cause: error,
      );
    }
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
