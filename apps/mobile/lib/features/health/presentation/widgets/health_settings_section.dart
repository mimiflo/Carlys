import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/health_connection.dart';
import '../controllers/health_connection_controller.dart';
import '../providers/health_providers.dart';
import 'health_connection_dialogs.dart';

/// Groupe « SANTÉ CONNECTÉE » des réglages : l'interrupteur, l'objectif de
/// pas une fois connecté, et — quand ça bloque — ce qui bloque, avec le
/// geste qui en sort. Aucun appel au greffon ici : tout passe par
/// [HealthConnectionController].
class HealthSettingsSection extends ConsumerWidget {
  const HealthSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(healthConnectionProvider).valueOrNull;
    // Tant qu'on ne sait pas, on se tait : une bascule qui ne reflète rien
    // vaut moins que pas de bascule.
    if (settings == null) return const SizedBox.shrink();
    final controller = ref.read(healthConnectionProvider.notifier);

    Future<void> connect() async {
      final status = await controller.connect();
      if (!context.mounted) return;
      if (status == HealthConnectionStatus.refused &&
          await confirmHealthRetry(context) &&
          context.mounted) {
        await connect();
      } else if (status == HealthConnectionStatus.needsInstall &&
          await confirmHealthConnectInstall(context)) {
        await controller.installHealthConnect();
      }
    }

    return AppSettingsGroup(
      label: 'Santé connectée',
      rows: [
        AppSettingsRow(
          icon: AppIcons.connectedHealth,
          label: 'Santé connectée',
          value: healthPlatformName(),
          toggleValue: settings.connected,
          onToggle: (on) => on ? connect() : controller.disconnect(),
        ),
        ...switch (settings.status) {
          HealthConnectionStatus.connected => [
            AppSettingsRow(
              icon: AppIcons.steps,
              label: 'Objectif de pas',
              value: '${formatThousands(settings.stepsGoal)} pas',
              valueIsMono: true,
              onTap: () async {
                final goal = await promptStepsGoal(context, settings.stepsGoal);
                if (goal != null) await controller.setStepsGoal(goal);
              },
            ),
          ],
          HealthConnectionStatus.refused => [
            AppSettingsRow(
              icon: AppIcons.healthBlocked,
              label: 'Accès refusé : voir comment l’autoriser',
              onTap: () async {
                if (await confirmHealthRetry(context) && context.mounted) {
                  await connect();
                }
              },
            ),
          ],
          HealthConnectionStatus.needsInstall => [
            AppSettingsRow(
              icon: AppIcons.healthBlocked,
              label: 'Health Connect n’est pas installé',
              value: 'Installer',
              onTap: controller.installHealthConnect,
            ),
          ],
          HealthConnectionStatus.unsupported => [
            const AppSettingsRow(
              icon: AppIcons.healthBlocked,
              label: 'Indisponible sur ce téléphone (Android 9 au minimum)',
            ),
          ],
          HealthConnectionStatus.off => const <AppSettingsRow>[],
        },
      ],
    );
  }
}
