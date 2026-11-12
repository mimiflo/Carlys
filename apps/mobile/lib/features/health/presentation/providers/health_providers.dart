import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/utilities/current_day.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../progress/data/repositories/progress_repository_impl.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../data/health_plugin_data_source.dart';
import '../../data/health_prefs_store.dart';
import '../../domain/health_data_source.dart';
import '../../domain/usecases/import_health_weighings.dart';
import '../../domain/usecases/read_today_steps.dart';
import '../controllers/health_connection_controller.dart';

/// Le greffon, derrière son port. Les tests le remplacent par
/// `FakeHealthDataSource` : aucun ne touche Health Connect.
final healthDataSourceProvider = Provider<HealthDataSource>(
  (ref) => HealthPluginDataSource(),
);

final healthPrefsStoreProvider = Provider<HealthPrefsStore>(
  (ref) => const HealthPrefsStore(),
);

/// Le compte dont on lit la connexion — `null` hors session.
final healthAccountIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).user?.id,
);

/// Le nom de la passerelle de CE téléphone, tel que la personne la connaît.
String healthPlatformName() => defaultTargetPlatform == TargetPlatform.iOS
    ? 'Apple Santé'
    : 'Health Connect';

/// Fréquence de relecture des pas, accueil ouvert. Cinq minutes : assez pour
/// voir la marche du matin compter, sans réveiller Health Connect sans cesse.
const Duration stepsRefreshInterval = Duration(minutes: 5);

/// Les pas du jour, ou `null` (non connecté, ou lecture impossible).
///
/// Relus à l'ouverture, au RETOUR AU PREMIER PLAN, toutes les cinq minutes
/// tant qu'on les regarde, et au passage de minuit. Ils ne vont nulle part :
/// aucun appel d'API, aucune écriture.
final todayStepsProvider = FutureProvider.autoDispose<int?>((ref) async {
  ref.watch(currentDayProvider);
  // Armés AVANT toute attente : un provider détruit pendant l'`await` ne
  // doit pas laisser un minuteur ni un écouteur derrière lui.
  final timer = Timer(stepsRefreshInterval, ref.invalidateSelf);
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(() {
    timer.cancel();
    lifecycle.dispose();
  });
  final settings = await ref.watch(healthConnectionProvider.future);
  if (!settings.connected) return null;
  try {
    final steps = await ReadTodaySteps(ref.watch(healthDataSourceProvider))(
      DateTime.now(),
    );
    // Le greffon rend `null` quand la lecture échoue, sans dire pourquoi :
    // l'écran écrit « lecture impossible », le journal garde la trace.
    if (steps == null) _stepsLog.warning('lecture des pas impossible');
    return steps;
  } catch (error) {
    _stepsLog.warning('lecture des pas en échec', error: error);
    rethrow;
  }
});

const _stepsLog = AppLogger('TodaySteps');

/// L'import des pesées, déclenché par l'écran Progrès (ouverture et retour au
/// premier plan).
class HealthWeighingImport {
  HealthWeighingImport(this._ref);

  final Ref _ref;

  /// L'import en cours : ouverture et retour au premier plan peuvent se
  /// croiser, un SEUL import tourne, les autres l'attendent.
  Future<void>? _running;

  static const _log = AppLogger('HealthWeighingImport');

  /// Sans effet hors connexion. Un échec (hors ligne) est JOURNALISÉ et
  /// reporté au prochain import : le curseur n'a pas bougé, rien n'est perdu.
  Future<void> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    final userId = _ref.read(healthAccountIdProvider);
    if (userId == null) return;
    try {
      final settings = await _ref.read(healthConnectionProvider.future);
      if (!settings.connected) return;
      final stored = await ImportHealthWeighings(
        source: _ref.read(healthDataSourceProvider),
        metrics: _ref.read(progressRepositoryProvider),
        ledger: _ref.read(healthPrefsStoreProvider),
      )(userId: userId, now: DateTime.now().toUtc());
      // La courbe ne se relit que si un POIDS qu'elle n'a pas est arrivé.
      // ponytail: une pesée SUPPRIMÉE relue dans la fenêtre de recouvrement
      // compte aussi pour « absente » (le serveur la renvoie) : une relecture
      // de trop, au plus une par quart d'heure ; un marqueur serveur si ça
      // pèse.
      final shown = _ref.read(bodyWeightMetricsProvider).valueOrNull;
      final known = {
        for (final entry in shown ?? const <BodyMetricEntry>[]) entry.id,
      };
      final fresh = stored.any(
        (entry) =>
            entry.kind == BodyMetricKind.weightKg && !known.contains(entry.id),
      );
      if (fresh) _ref.invalidate(bodyWeightMetricsProvider);
    } catch (error) {
      _log.warning('import des pesées reporté', error: error);
    }
  }
}

final healthWeighingImportProvider = Provider<HealthWeighingImport>(
  HealthWeighingImport.new,
);
