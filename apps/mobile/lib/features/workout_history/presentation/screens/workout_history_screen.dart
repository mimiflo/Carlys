import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../widgets/history_calendar.dart';

/// Historique (maquette 2g) : sélecteur de mois, grille calendaire
/// (séances en violet, records en accent), liste des séances du mois.
class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutHistoryProvider);
    final records = ref.watch(personalRecordsProvider).valueOrNull;
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Historique'),
      ),
      body: SafeArea(
        child: history.when(
          loading: () => const AppLoadingIndicator(label: 'Chargement'),
          error: (_, __) =>
              const AppErrorState(title: 'Historique indisponible'),
          data: (entries) {
            if (entries.isEmpty) {
              return const AppEmptyState(
                title: 'Aucune séance terminée',
                message: 'Vos séances apparaîtront ici une fois clôturées.',
                icon: AppIcons.history,
              );
            }
            final monthEntries = entries.where((entry) {
              final local = entry.session.startedAt.toLocal();
              return local.year == _month.year && local.month == _month.month;
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Mois précédent',
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          formatMonth(_month),
                          style: AppTypography.subheading
                              .copyWith(color: AppColors.darkTextPrimary),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mois suivant',
                      onPressed: isCurrentMonth ? null : () => _shiftMonth(1),
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: isCurrentMonth
                            ? AppColors.darkTextTertiary
                            : AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                HistoryCalendar(
                  month: _month,
                  entries: monthEntries,
                  records: records,
                ),
                const SizedBox(height: AppSpacing.gapSection),
                if (monthEntries.isEmpty)
                  const AppEmptyState(
                    title: 'Aucune séance ce mois-ci',
                    message: 'Change de mois avec les flèches ci-dessus.',
                    icon: AppIcons.history,
                  )
                else
                  for (final entry in monthEntries) ...[
                    _HistoryRow(entry: entry),
                    const SizedBox(height: AppSpacing.xs),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final WorkoutHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final session = entry.session;
    final local = session.startedAt.toLocal();
    final trailing = session.syncState != LocalSyncState.synced
        ? Icon(
            session.syncState == LocalSyncState.failed
                ? AppIcons.error
                : AppIcons.offline,
            size: 16,
            color: session.syncState == LocalSyncState.failed
                ? AppColors.danger
                : AppColors.darkTextTertiary,
          )
        : null;

    return Semantics(
      label: 'Séance du ${local.day} ${formatMonth(local)}',
      button: true,
      child: AppListRow(
        title: session.name ?? 'Séance libre',
        subtitle: '${local.day.toString().padLeft(2, '0')} '
            '${formatMonth(local).split(' ').first} · '
            '${entry.setsCount} séries',
        leading: AppIcons.history,
        trailing: trailing,
        trailingText:
            trailing == null ? '${entry.totalVolumeKg.round()} kg' : null,
        onTap: () => context.push(AppRoutes.workoutDetail(session.id)),
      ),
    );
  }
}
