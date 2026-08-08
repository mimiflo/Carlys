import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../core/synchronization/sync_engine.dart';
import '../../features/workout_session/data/repositories/workout_repository_impl.dart';
import '../../features/workout_session/domain/repositories/workout_repository.dart';
import '../../features/workout_template/data/repositories/workout_template_repository_impl.dart';
import '../../features/workout_template/domain/repositories/workout_template_repository.dart';

/// **Rapatriement au démarrage** : remet dans la base locale ce que le serveur
/// détient déjà.
///
/// Sans lui, un téléphone neuf (réinstallation, changement d'appareil) démarre
/// sur une base vide : ni historique, ni modèles, et une séance commencée
/// ailleurs reste introuvable. C'est le pendant en LECTURE de la file de
/// synchronisation, qui, elle, ne fait que pousser.
///
/// Trois principes :
///  - **pousser avant de tirer** : les opérations locales en attente partent
///    d'abord, sinon elles feraient barrage (une saisie non acquittée bloque
///    volontairement la réécriture de sa séance) ;
///  - **jamais bloquant** : hors ligne, l'échec est journalisé et l'écran
///    s'affiche normalement sur les données locales ;
///  - **une seule fois par session applicative**, comme les déclencheurs de
///    synchronisation.
class AppRestore {
  AppRestore({
    required SyncEngine syncEngine,
    required WorkoutRepository workouts,
    required WorkoutTemplateRepository templates,
  })  : _sync = syncEngine,
        _workouts = workouts,
        _templates = templates;

  static const _logger = AppLogger('AppRestore');

  final SyncEngine _sync;
  final WorkoutRepository _workouts;
  final WorkoutTemplateRepository _templates;
  bool _started = false;

  void ensureRestored() {
    if (_started) {
      return;
    }
    _started = true;
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      await _sync.syncNow();
      await _templates.refreshTemplates();
      await _workouts.restoreSessions();
    } on Exception catch (exception) {
      // Hors ligne ou serveur indisponible : l'application vit sur son local,
      // le prochain démarrage réessaiera.
      _logger.warning(
        'Rapatriement impossible pour le moment',
        error: exception,
      );
    }
  }
}

final appRestoreProvider = Provider<AppRestore>((ref) {
  return AppRestore(
    syncEngine: ref.watch(syncEngineProvider),
    workouts: ref.watch(workoutRepositoryProvider),
    templates: ref.watch(workoutTemplateRepositoryProvider),
  );
});
