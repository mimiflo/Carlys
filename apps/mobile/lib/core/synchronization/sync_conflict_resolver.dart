import 'dart:convert';

import '../database/app_database.dart';

/// Verdict rendu sur un `409 CONFLICT` reçu à la clôture d'une séance.
///
/// Le serveur ne répond 409 à `session.complete` / `session.abandon` que si
/// la séance est déjà close **avec une autre issue** (re-clôturer avec la
/// même issue est un rejeu, servi en 200). Le résolveur va lire la version
/// serveur pour trancher entre ces cas.
enum SyncConflictVerdict {
  /// Le serveur a la même issue (course entre le 409 et la lecture) : sa
  /// version a été rapatriée en local, l'opération est acquittée.
  adopted,

  /// Le serveur a clôturé autrement : c'est à l'utilisateur de choisir.
  conflict,

  /// Impossible de lire la version serveur pour l'instant (hors ligne,
  /// serveur indisponible) : on retentera, le 409 reviendra et on tranchera.
  retryLater,

  /// La séance n'existe pas (plus) pour ce compte sur le serveur : refus
  /// définitif, rien à arbitrer.
  rejected,
}

/// Tranche un conflit de clôture. Implémenté par la fonctionnalité séance,
/// qui seule sait lire et écrire une séance complète.
abstract interface class SyncConflictResolver {
  Future<SyncConflictVerdict> resolveClose(SyncOperation operation);
}

/// Marqueur, dans la charge utile, d'une opération que l'utilisateur a
/// choisi de **rejouer telle quelle** après un conflit (« garder ma
/// version »). Si le serveur refuse encore, l'opération passe en échec
/// définitif au lieu de revenir en conflit : l'utilisateur a déjà tranché,
/// on ne lui repose pas la question.
const String syncResolutionKey = 'resolution';
const String syncKeepLocalResolution = 'keepLocal';

/// Vrai si [operation] rejoue une version locale déjà arbitrée.
bool isArbitratedKeepLocal(SyncOperation operation) {
  try {
    final payload = jsonDecode(operation.payload);
    return payload is Map<String, dynamic> &&
        payload[syncResolutionKey] == syncKeepLocalResolution;
  } on FormatException {
    return false; // charge illisible : l'envoi la marquera en échec
  }
}
