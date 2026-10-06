import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/account_session.dart';

/// Garde une lecture serveur AUTO-DISPOSÉE ([read]) en vie [duration] après
/// qu'elle a été lue — et la relit au changement de compte.
///
/// Entre les deux formes du dépôt : un provider auto-disposé se relisait à
/// CHAQUE retour sur son écran (un onglet quitté puis repris : toutes ses
/// requêtes, et un indicateur de chargement, à chaque fois) ; un
/// [AccountBoundCache] ne se relit plus jamais seul, ce qui ne convient pas à
/// un fil d'amis ou à un classement qui bougent. Ici, un retour dans les deux
/// minutes est servi tel quel ; au-delà, l'écran suivant relit.
///
/// La session ([accountSessionProvider]) est ÉCOUTÉE : la valeur gardée du
/// compte parti ne survit pas à l'arrivée du suivant. Et un ÉCHEC n'est
/// jamais gardé : hors ligne, l'écran suivant réessaie, comme avant.
Future<T> keepForAccount<T>(
  Ref<Object?> ref,
  Future<T> Function() read, {
  Duration duration = const Duration(minutes: 2),
}) {
  // Sans session, rien n'est demandé : l'écran qui écoute encore (le Profil
  // pendant la déconnexion) ne tire pas une salve de 401.
  if (ref.watch(accountSessionProvider) == null) {
    return Future<T>.error(const SignedOutException());
  }
  final link = ref.keepAlive();
  final timer = Timer(duration, link.close);
  ref.onDispose(timer.cancel);
  return read().catchError((Object error, StackTrace stack) {
    link.close();
    Error.throwWithStackTrace(error, stack);
  });
}

/// La lecture d'un compte, demandée alors qu'aucun n'est ouvert.
class SignedOutException implements Exception {
  const SignedOutException();
}
