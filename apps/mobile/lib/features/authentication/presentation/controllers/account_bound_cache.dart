import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_session.dart';

/// UN CACHE SERVEUR QUI APPARTIENT AU COMPTE, ET À LA SESSION QUI L'A LU.
///
/// Le défaut qu'il ferme, sur un téléphone partagé : A se déconnecte depuis
/// le Profil, l'accueil encore monté. Un `FutureProvider` permanent qu'on
/// invalide se relit aussitôt s'il est écouté — sans session, donc en 401 —
/// et Riverpod GARDE la valeur précédente dans l'erreur, comme pendant tout
/// rechargement. Rien ne le relisait à l'entrée de B : B héritait des 200
/// séances de A, gagnait ses médailles et les poussait sur son propre
/// serveur.
///
/// Trois règles, une par défaut :
///
/// 1. Relu à CHAQUE passage de la frontière ([accountSessionProvider]) : le
///    compte qui arrive lit le sien, sans qu'on pense à l'invalider.
/// 2. Sans session, rien n'est demandé au serveur : le cache vaut [none],
///    ce que vaut un compte absent (zéro séance, aucun record…).
/// 3. La valeur d'une AUTRE session ne survit pas au rechargement. Riverpod
///    la conserve pendant la relecture et à travers un échec — voulu pour
///    le même compte hors ligne (les médailles ne disparaissent pas le temps
///    de retrouver le réseau), fautif d'un compte à l'autre. Seul un
///    `AsyncData` efface la valeur précédente : la relecture repart donc de
///    [none]. Le compte qui arrive voit « rien encore », jamais celui d'un
///    autre, et un premier échec chez lui ne ressuscite pas l'ancien.
///
/// Tout cache serveur PERMANENT du compte en est un. Pas seulement ceux
/// qu'un `valueOrNull` lit : `.when` aussi montre la donnée précédente
/// pendant une relecture forcée, et la purge du compte en force une.
class AccountBoundCache<T> extends AsyncNotifier<T> {
  AccountBoundCache(this._read, {required this.none});

  /// La lecture réseau, faite pour le compte de la session ouverte. Ses
  /// `ref.watch` sont ceux du cache : une dépendance qui change le relit.
  final Future<T> Function(Ref ref) _read;

  /// Ce que vaut le cache sans compte : il ne contient rien de personne.
  final T none;

  /// La session pour laquelle la valeur exposée a été lue. L'instance du
  /// notifier survit aux reconstructions, c'est elle qui s'en souvient.
  int? _readFor;
  bool _hasRead = false;

  @override
  FutureOr<T> build() {
    final session = ref.watch(accountSessionProvider);
    final previousSession = _readFor;
    final foreign = _hasRead && previousSession != session;
    _hasRead = true;
    _readFor = session;
    if (session == null) return none;
    if (foreign) {
      // Deux temps : la donnée vide efface la valeur de l'autre session, le
      // chargement dit que celle de la session ouverte est en route.
      state = AsyncData(none);
      state = AsyncLoading<T>();
    }
    return _read(ref);
  }
}

/// Déclare un [AccountBoundCache] : `accountBoundCache(lecture, none: vide)`.
AsyncNotifierProvider<AccountBoundCache<T>, T> accountBoundCache<T>(
  Future<T> Function(Ref ref) read, {
  required T none,
}) => AsyncNotifierProvider<AccountBoundCache<T>, T>(
  () => AccountBoundCache<T>(read, none: none),
);
