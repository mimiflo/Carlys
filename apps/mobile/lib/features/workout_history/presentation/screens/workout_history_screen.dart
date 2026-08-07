import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';

/// Historique des séances (données locales, synchronisées en arrière-plan).
class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: SafeArea(
        child: history.when(
          loading: () => const AppLoadingIndicator(label: 'Chargement'),
          error: (_, __) =>
              const AppErrorState(title: 'Historique indisponible'),
          data: (entries) => entries.isEmpty
              ? const AppEmptyState(
                  title: 'Aucune séance terminée',
                  message: 'Vos séances apparaîtront ici une fois clôturées.',
                  icon: AppIcons.history,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _HistoryTile(entry: entries[index]),
                ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final WorkoutHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = entry.session;

    return AppCard(
      onTap: () => context.push(AppRoutes.workoutDetail(session.id)),
      semanticLabel: 'Séance du ${_formatDate(session.startedAt)}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name ?? 'Séance du ${_formatDate(session.startedAt)}',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${entry.setsCount} série(s) — '
                  '${entry.totalVolumeKg.round()} kg — '
                  '${_formatDuration(session.durationSeconds)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppBadge(
                label: session.status.label,
                variant: session.status == WorkoutStatus.completed
                    ? AppBadgeVariant.primary
                    : AppBadgeVariant.neutral,
              ),
              if (session.syncState != LocalSyncState.synced) ...[
                const SizedBox(height: AppSpacing.xxs),
                Icon(
                  session.syncState == LocalSyncState.failed
                      ? AppIcons.error
                      : AppIcons.offline,
                  size: 16,
                  color: session.syncState == LocalSyncState.failed
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime utc) {
  final local = utc.toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year}';
}

String _formatDuration(int? seconds) {
  if (seconds == null) {
    return '—';
  }
  final minutes = seconds ~/ 60;
  return minutes >= 60
      ? '${minutes ~/ 60} h ${minutes % 60} min'
      : '$minutes min';
}
