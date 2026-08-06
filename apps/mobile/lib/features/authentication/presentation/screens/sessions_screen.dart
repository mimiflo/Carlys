import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/auth_session_device.dart';
import '../controllers/sessions_controller.dart';

/// Gestion des appareils connectés : liste des sessions actives,
/// déconnexion ciblée ou de tous les autres appareils.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appareils connectés')),
      body: SafeArea(
        child: sessions.when(
          loading: () =>
              const AppLoadingIndicator(label: 'Chargement des appareils'),
          error: (error, _) => AppErrorState(
            title: 'Impossible de charger les appareils',
            message: 'Vérifiez votre connexion puis réessayez.',
            onRetry: () => ref.invalidate(sessionsControllerProvider),
          ),
          data: (devices) => _SessionsList(devices: devices),
        ),
      ),
    );
  }
}

class _SessionsList extends ConsumerWidget {
  const _SessionsList({required this.devices});

  final List<AuthSessionDevice> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = devices.where((device) => !device.current).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final device in devices) _SessionTile(device: device),
        if (others > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Déconnecter tous les autres appareils',
            variant: AppButtonVariant.destructive,
            isExpanded: true,
            onPressed: () async {
              final confirmed = await _confirm(
                context,
                'Déconnecter les autres appareils ?',
                'Les $others autre(s) appareil(s) devront se reconnecter.',
              );
              if (confirmed) {
                await ref
                    .read(sessionsControllerProvider.notifier)
                    .revokeOthers();
              }
            },
          ),
        ],
      ],
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.device});

  final AuthSessionDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(
          device.devicePlatform == 'ios' || device.devicePlatform == 'android'
              ? Icons.smartphone
              : Icons.devices_other,
          color: theme.colorScheme.primary,
        ),
        title: Text(device.label),
        subtitle: Text(
          device.current
              ? 'Cet appareil'
              : 'Dernière activité : ${_formatDate(device.lastUsedAt)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: device.current
            ? null
            : IconButton(
                tooltip: 'Déconnecter cet appareil',
                icon: Icon(Icons.logout, color: theme.colorScheme.error),
                onPressed: () async {
                  final confirmed = await _confirm(
                    context,
                    'Déconnecter cet appareil ?',
                    '« ${device.label} » devra se reconnecter.',
                  );
                  if (confirmed) {
                    await ref
                        .read(sessionsControllerProvider.notifier)
                        .revoke(device.id);
                  }
                },
              ),
      ),
    );
  }
}

String _formatDate(DateTime utc) {
  final local = utc.toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year} '
      '${pad(local.hour)}:${pad(local.minute)}';
}

Future<bool> _confirm(BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
  return result ?? false;
}
