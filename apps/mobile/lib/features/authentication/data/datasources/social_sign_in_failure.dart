import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../domain/entities/social_provider.dart';
import '../../domain/entities/social_sign_in_unavailable.dart';

// Ce fichier NOMME les échecs des SDK Apple et Google : lui seul lit leurs
// exceptions. Les types qu'il produit vivent dans le domaine
// (`social_sign_in_unavailable.dart`), pour que la présentation puisse les
// classer sans toucher à la couche données.

/// Longueur maximale de la partie variable d'un code : de quoi porter
/// `failed_to_recover_auth`, pas de quoi recopier un message entier.
const int _fragmentMax = 24;

/// Statut des services Google Play tel qu'il arrive dans le message d'une
/// `PlatformException` : `ApiException.toString()`, soit
/// « com.google.android.gms.common.api.ApiException: 12500: »
/// (`GoogleSignInPlugin.onSignInResult`). Le `\b` évite de lire 10 dans 100.
final RegExp _apiStatus = RegExp(r'ApiException:\s*(\d{1,6})\b');

/// Code de canal du générateur Pigeon (`_createConnectionError`, dans le
/// `messages.g.dart` de google_sign_in_android 6.2.1 comme de
/// google_sign_in_ios 5.9.0) : le côté natif n'a RIEN répondu. Les deux
/// greffons parlent Pigeon, pas `MethodChannel` : un greffon absent y lève
/// ce code, jamais une `MissingPluginException`.
const String _pigeonNoReply = 'channel-error';

/// Code fabriqué par le `wrapError` de Pigeon quand le côté natif lève une
/// exception Java qui n'est pas une `FlutterError` : son `toString()`, soit
/// `java.lang.IllegalStateException: …` suivi d'un message libre. Seul le
/// nom court de la classe est retenu : le message n'a rien d'un code stable.
final RegExp _javaThrowable = RegExp(
  r'^(?:[a-z_][\w$]*\.)+([A-Z][\w$]*?)(?:Exception|Error)?(?::|$)',
);

/// Réduit un code venu d'un SDK à un fragment sûr : minuscules, chiffres,
/// `_` et `-`, longueur bornée. `invalidResponse` devient
/// `invalid-response` ; tout autre caractère devient un tiret. Aucun texte
/// libre du fournisseur n'arrive ainsi jusqu'à l'écran.
String codeFragment(String raw) {
  final kebab = raw.replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (match) => '${match[1]}-${match[2]}',
  );
  var fragment = kebab
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9_]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  if (fragment.length > _fragmentMax) {
    fragment = fragment
        .substring(0, _fragmentMax)
        .replaceAll(RegExp(r'-+$'), '');
  }
  return fragment.isEmpty ? 'inconnu' : fragment;
}

/// Traduit TOUT échec du SDK Google en obstacle nommé et en code court.
///
/// Les codes et messages viennent de `GoogleSignInPlugin.java`
/// (google_sign_in_android 6.2.1) : `errorCodeForStatus` rend
/// `sign_in_required` (4), `network_error` (7) et `sign_in_failed` pour tout
/// le reste — 10, 12500… —, avec `ApiException.toString()` pour message ;
/// `exception`, `status`, `user_recoverable_auth` et
/// `failed_to_recover_auth` viennent d'autres chemins et ne portent aucun
/// statut. Le statut, quand il y en a un, l'emporte : `sign_in_failed`
/// recouvre à lui seul des causes que rien d'autre ne distingue.
SocialSignInUnavailable googleFailure(Object error) {
  const google = SocialProvider.google;
  if (error is PlatformException) {
    final status = _apiStatus.firstMatch(error.message ?? '')?.group(1);
    if (status != null) {
      return SocialSignInUnavailable(
        google,
        switch (status) {
          '10' => SocialSignInObstacle.identiteAppareil,
          '7' => SocialSignInObstacle.reseau,
          _ => SocialSignInObstacle.echec,
        },
        code: 'google-$status',
        cause: error,
      );
    }
    if (error.code == _pigeonNoReply) return _unexpected(google, error);
    return SocialSignInUnavailable(
      google,
      error.code == 'network_error'
          ? SocialSignInObstacle.reseau
          : SocialSignInObstacle.echec,
      code: 'google-${_channelCode(error.code)}',
      cause: error,
    );
  }
  return _unexpected(google, error);
}

/// Le code de canal d'une `PlatformException`, réduit à un fragment sûr.
/// Une exception Java enveloppée par Pigeon n'en garde que la classe :
/// `java-illegal-state`, jamais son message.
String _channelCode(String raw) {
  final javaClass = _javaThrowable.firstMatch(raw)?.group(1);
  return javaClass == null
      ? codeFragment(raw)
      : 'java-${codeFragment(javaClass)}';
}

/// Traduit un échec du SDK Apple. L'annulation n'arrive JAMAIS ici : c'est
/// un renoncement, la passerelle le rend en `null` avant d'appeler.
SocialSignInUnavailable appleFailure(Object error) {
  const apple = SocialProvider.apple;
  // Les trois exceptions nommées du greffon naissent d'une
  // `PlatformException` (`SignInWithAppleException.fromPlatformException`) :
  // on leur rend le code de canal qui les a produites, `not-supported` et
  // `credentials-error`. `UnknownSignInWithAppleException` en EST une.
  final raw = switch (error) {
    SignInWithAppleAuthorizationException(code: final reason) => reason.name,
    SignInWithAppleNotSupportedException() => 'not-supported',
    SignInWithAppleCredentialsException() => 'credentials-error',
    PlatformException(code: final channelCode) => channelCode,
    _ => null,
  };
  if (raw == null) return _unexpected(apple, error);
  return SocialSignInUnavailable(
    apple,
    SocialSignInObstacle.echec,
    code: 'apple-${codeFragment(raw)}',
    cause: error,
  );
}

/// Ce que le SDK lève HORS de ses codes d'échec : le côté natif qui ne
/// répond pas, ou toute autre erreur — la `StateError('User is no longer
/// signed in.')` de `GoogleSignInAccount.authentication`, par exemple.
/// Enveloppée ici, elle garde le nom de son fournisseur au lieu de finir en
/// échec anonyme.
///
/// `<fournisseur>-plugin` quand le natif n'a pas répondu : greffon absent
/// du build (`MissingPluginException` d'un greffon à `MethodChannel`, comme
/// Apple ; `channel-error` d'un greffon Pigeon, comme Google), ou exception
/// Java levée hors du canal d'erreur du greffon. Sur Android, le moteur la
/// rattrape (`DartMessenger` : « Uncaught exception in binary message
/// listener ») et répond VIDE : `GoogleSignInPlugin` lève ainsi
/// « signIn needs a foreground activity » et « Concurrent operations
/// detected », qui arrivent donc en `channel-error`.
SocialSignInUnavailable _unexpected(SocialProvider provider, Object error) {
  final silent =
      error is MissingPluginException ||
      (error is PlatformException && error.code == _pigeonNoReply);
  return SocialSignInUnavailable(
    provider,
    SocialSignInObstacle.echec,
    code: silent
        ? '${provider.wireName}-plugin'
        : '${provider.wireName}-inattendu',
    cause: error,
  );
}
