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
    required this._workouts,
    required this._templates,
  }) : _sync = syncEngine;

  static const _logger = AppLogger('AppRestore');

  final SyncEngine _sync;
  final WorkoutRepository _workouts;
  final WorkoutTemplateRepository _templates;
  bool _started = false;
  bool _cancelled = false;
  Future<void>? _running;

  void ensureRestored() {
    if (_started) {
      return;
    }
    _started = true;
    final run = _run();
    _running = run;
    unawaited(run);
  }

  /// Annule le rapatriement et ATTEND qu'il ait rendu la main.
  ///
  /// La purge de compte l'appelle AVANT de vider la base : invalider le
  /// provider n'arrête pas un futur déjà lancé, et une écriture du
  /// rapatriement qui aboutissait entre le vidage et la fermeture
  /// réinjectait les séances de l'ancien compte dans le fichier SQLite que
  /// le compte suivant rouvre. Après le retour de cette méthode, plus
  /// aucune écriture du rapatriement ne touchera la base.
  Future<void> cancelAndWait() async {
    _cancelled = true;
    await (_running ?? Future<void>.value());
  }

  Future<void> _run() async {
    try {
      await _sync.syncNow();
      if (_cancelled) {
        return;
      }
      await _templates.refreshTemplates();
      if (_cancelled) {
        return;
      }
      await _workouts.restoreSessions(shouldContinue: () => !_cancelled);
    } on Exception catch (exception) {
      // Hors ligne ou serveur indisponible : l'application vit sur son local,
      // le prochain démarrage réessaiera.
      _logger.warning(
        'Rapatriement impossible pour le moment',
        error: exception,
      );
    } on StateError catch (error) {
      // Base Drift fermée sous nos pieds (purge de compte pendant le
      // rapatriement) : le moteur de synchronisation attrape ce cas exprès,
      // ici il finissait en erreur asynchrone non gérée.
      _logger.warning('Rapatriement interrompu par la purge', error: error);
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
