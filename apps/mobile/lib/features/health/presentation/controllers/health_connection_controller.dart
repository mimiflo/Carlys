import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/health_connection.dart';
import '../../domain/health_data_source.dart';
import '../providers/health_providers.dart';

/// La connexion à Health Connect / Apple Santé, et l'objectif de pas.
///
/// L'interrupteur des réglages la pilote ; l'accueil (pas) et Progrès
/// (pesées) la lisent. Mémorisée sur l'appareil, par compte
/// (`HealthPrefsStore`) — et revérifiée à chaque lecture : une autorisation
/// retirée dans Health Connect passe la connexion en « refusée », avec la
/// marche à suivre, au lieu d'afficher zéro pas sans rien dire.
class HealthConnectionController extends AsyncNotifier<HealthSettings> {
  @override
  Future<HealthSettings> build() async {
    final userId = ref.watch(healthAccountIdProvider);
    if (userId == null) {
      return const HealthSettings(status: HealthConnectionStatus.off);
    }
    final store = ref.watch(healthPrefsStoreProvider);
    final goal =
        await store.stepsGoal(userId) ?? HealthSettings.defaultStepsGoal;
    if (!await store.isConnected(userId)) {
      return HealthSettings(
        status: HealthConnectionStatus.off,
        stepsGoal: goal,
      );
    }
    final granted = await ref.watch(healthDataSourceProvider).hasReadAccess();
    return HealthSettings(
      status: granted
          ? HealthConnectionStatus.connected
          : HealthConnectionStatus.refused,
      stepsGoal: goal,
    );
  }

  /// Demande les trois lectures. Rend le statut obtenu, pour que l'écran
  /// explique un refus ou une installation manquante sur le moment.
  Future<HealthConnectionStatus> connect() async {
    final userId = ref.read(healthAccountIdProvider);
    if (userId == null) return HealthConnectionStatus.off;
    final source = ref.read(healthDataSourceProvider);
    final store = ref.read(healthPrefsStoreProvider);

    final status = switch (await source.availability()) {
      HealthAvailability.needsInstall => HealthConnectionStatus.needsInstall,
      HealthAvailability.unsupported => HealthConnectionStatus.unsupported,
      HealthAvailability.available =>
        await source.requestReadAccess()
            ? HealthConnectionStatus.connected
            : HealthConnectionStatus.refused,
    };
    await store.setConnected(
      userId,
      connected: status == HealthConnectionStatus.connected,
    );
    _publish(status);
    return status;
  }

  /// Carlys cesse de lire. L'autorisation, elle, se retire dans Health
  /// Connect ou dans Réglages > Santé : Carlys ne peut pas le faire à ta
  /// place sur iOS, et Android ne l'applique qu'au redémarrage.
  Future<void> disconnect() async {
    final userId = ref.read(healthAccountIdProvider);
    if (userId == null) return;
    await ref
        .read(healthPrefsStoreProvider)
        .setConnected(userId, connected: false);
    _publish(HealthConnectionStatus.off);
  }

  Future<void> setStepsGoal(int goal) async {
    final userId = ref.read(healthAccountIdProvider);
    if (userId == null) return;
    final bounded = goal.clamp(
      HealthSettings.minStepsGoal,
      HealthSettings.maxStepsGoal,
    );
    await ref.read(healthPrefsStoreProvider).setStepsGoal(userId, bounded);
    final current = state.valueOrNull;
    state = AsyncData(
      HealthSettings(
        status: current?.status ?? HealthConnectionStatus.off,
        stepsGoal: bounded,
      ),
    );
  }

  Future<void> installHealthConnect() =>
      ref.read(healthDataSourceProvider).installHealthConnect();

  void _publish(HealthConnectionStatus status) {
    state = AsyncData(
      HealthSettings(
        status: status,
        stepsGoal:
            state.valueOrNull?.stepsGoal ?? HealthSettings.defaultStepsGoal,
      ),
    );
  }
}

final healthConnectionProvider =
    AsyncNotifierProvider<HealthConnectionController, HealthSettings>(
      HealthConnectionController.new,
    );
