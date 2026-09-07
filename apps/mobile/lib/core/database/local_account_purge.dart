import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/restore/app_restore.dart';
import '../../features/academy/data/answered_lessons_store.dart';
import '../../features/progression/data/reward_ledger.dart';
import '../logging/app_logger.dart';
import '../synchronization/sync_lifecycle.dart';
import 'app_database.dart';

/// Efface tout ce que l'appareil garde POUR UN COMPTE, à la frontière de
/// compte (déconnexion, expiration de session, et demain suppression du
/// compte) : le compte suivant sur le même appareil repart de zéro et
/// déclenche son propre rapatriement.
///
/// Sans elle, le compte suivant voyait l'historique, les modèles et
/// l'hydratation du précédent, et la file de synchronisation partait avec
/// son jeton — les séances de l'un atterrissaient chez l'autre.
abstract interface class LocalAccountPurge {
  Future<void> run();
}

/// Purge réelle : base Drift entière, préférences propriétaires du compte,
/// puis renouvellement des providers qui tiennent l'état du compte.
class DriftLocalAccountPurge implements LocalAccountPurge {
  DriftLocalAccountPurge(this._ref);

  static const _logger = AppLogger('LocalAccountPurge');

  /// Préférences locales qui appartiennent au COMPTE, pas à l'appareil :
  /// le journal des récompenses et les questions d'Academy déjà abordées.
  /// Le thème, le parcours de première ouverture et ses réponses en attente
  /// restent : ils décrivent l'appareil et son premier lancement.
  static const List<String> accountOwnedPreferenceKeys = [
    RewardLedger.key,
    AnsweredLessonsStore.key,
  ];

  final Ref _ref;

  @override
  Future<void> run() async {
    // 1. Plus aucun déclencheur : ni drainage ni rapatriement ne doit
    //    démarrer sur la base qu'on s'apprête à vider.
    _ref.invalidate(syncLifecycleProvider);
    _ref.invalidate(appRestoreProvider);

    // 2. La base, d'un bloc, dans une transaction.
    await _ref.read(appDatabaseProvider).wipeAll();

    // 3. Les préférences du compte.
    final preferences = await SharedPreferences.getInstance();
    for (final key in accountOwnedPreferenceKeys) {
      await preferences.remove(key);
    }

    // 4. Une base neuve pour la suite : tout ce qui en dépend (moteur,
    //    dépôts, flux des écrans) se reconstruit dessus, et le prochain
    //    compte déclenchera son rapatriement comme un premier démarrage.
    _ref.invalidate(appDatabaseProvider);
    _logger.info('État local du compte purgé');
  }
}

final localAccountPurgeProvider = Provider<LocalAccountPurge>(
  DriftLocalAccountPurge.new,
);
