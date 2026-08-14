import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import 'sync_engine.dart';

/// Déclencheurs de synchronisation :
///  - à l'entrée dans l'application authentifiée ;
///  - au retour de la connectivité ;
///  - périodiquement (3 min), en filet de sécurité.
class SyncLifecycle {
  SyncLifecycle(this._engine);

  static const _logger = AppLogger('SyncLifecycle');
  static const period = Duration(minutes: 3);

  final SyncEngine _engine;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _timer;
  bool _started = false;

  void ensureStarted() {
    if (_started) {
      return;
    }
    _started = true;

    _poke();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((result) => result != ConnectivityResult.none);
      if (online) {
        _logger.info('Connectivité retrouvée : synchronisation');
        _poke();
      }
    });
    _timer = Timer.periodic(period, (_) => _poke());
  }

  void _poke() {
    unawaited(_engine.syncNow());
  }

  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    _timer?.cancel();
  }
}

final syncLifecycleProvider = Provider<SyncLifecycle>((ref) {
  final lifecycle = SyncLifecycle(ref.watch(syncEngineProvider));
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});
