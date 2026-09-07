/// Cycle de vie de la DÉMONSTRATION (flavor `demo`) : synchronisation,
/// rapatriement et purge, tous SANS EFFET.
///
/// Ce n'est pas de la paresse : la vraie purge et le vrai rapatriement
/// ouvriraient la base Drift, dont le mode démonstration se passe entièrement.
library;

import '../app/restore/app_restore.dart';
import '../core/database/local_account_purge.dart';
import '../core/synchronization/sync_lifecycle.dart';

/// Aucune synchronisation en démo : rien à pousser, aucun serveur à joindre.
class DemoSyncLifecycle implements SyncLifecycle {
  @override
  void ensureStarted() {}

  @override
  void dispose() {}
}

/// Aucun rapatriement en démo, pour la même raison — et surtout : ne pas
/// ouvrir la base Drift, dont le mode démo se passe entièrement.
class DemoAppRestore implements AppRestore {
  @override
  void ensureRestored() {}
}

/// Rien à purger en démo : tout vit en mémoire, et la vraie purge ouvrirait
/// la base Drift dont le mode démo se passe.
class DemoLocalAccountPurge implements LocalAccountPurge {
  @override
  Future<void> run() async {}
}
