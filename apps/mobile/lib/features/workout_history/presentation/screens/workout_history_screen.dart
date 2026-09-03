import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../utils/history_stats.dart';
import '../widgets/history_calendar.dart';
import '../widgets/history_header.dart';
import '../widgets/history_month_sheet.dart';
import '../widgets/history_session_card.dart';

/// Historique : carte calendaire du mois (chaleur = volume réel du jour,
/// accent = record) puis les séances du mois en cartes riches.
class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  /// Mois choisi dans la feuille ; `null` = mois courant.
  DateTime? _selectedMonth;

  DateTime get _month {
    final selected = _selectedMonth;
    if (selected != null) {
      return selected;
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  Future<void> _pickMonth() async {
    final history = ref.read(workoutHistoryProvider).valueOrNull ??
        const <WorkoutHistoryEntry>[];
    final chosen = await showHistoryMonthSheet(
      context,
      months: historyMonths(history, DateTime.now()),
      selected: _month,
    );
    if (chosen != null && mounted) {
      setState(() => _selectedMonth = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(workoutHistoryProvider);
    final records = ref.watch(personalRecordsProvider).valueOrNull ??
        const <PersonalRecordEntry>[];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.gutter,
            AppSpacing.gutter,
            AppSpacing.gutter + bottomInset,
          ),
          children: [
            HistoryHeader(onPickMonth: _pickMonth),
            const SizedBox(height: AppSpacing.md),
            history.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: AppLoadingIndicator(label: 'Chargement de l’historique'),
              ),
              error: (_, __) => AppErrorState(
                title: 'Historique indisponible',
                message: 'Vos séances n’ont pas pu être chargées.',
                onRetry: () => ref.invalidate(workoutHistoryProvider),
              ),
              data: (entries) => entries.isEmpty
                  ? const AppEmptyState(
                      title: 'Aucune séance terminée',
                      message:
                          'Vos séances apparaîtront ici une fois clôturées.',
                      icon: AppIcons.history,
                    )
                  : _MonthView(
                      stats: monthStats(
                        month: _month,
                        history: entries,
                        records: records,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenu du mois affiché : grille de chaleur puis liste des séances.
class _MonthView extends StatelessWidget {
  const _MonthView({required this.stats});

  final HistoryMonthStats stats;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        stats.month.year == now.year && stats.month.month == now.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HistoryCalendar(stats: stats),
        const SizedBox(height: AppSpacing.md),
        AppSectionLabel(
          isCurrentMonth ? 'Ce mois-ci' : formatMonthYear(stats.month),
          color: AppColors.darkTextTertiary,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (stats.entries.isEmpty)
          const AppEmptyState(
            title: 'Aucune séance ce mois-ci',
            message: 'Choisis un autre mois avec l’icône calendrier.',
            icon: AppIcons.history,
          )
        else
          for (var index = 0; index < stats.entries.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.gapTile),
            _SessionCard(entry: stats.entries[index], stats: stats),
          ],
      ],
    );
  }
}

/// Carte de séance branchée sur la navigation vers le détail.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.entry, required this.stats});

  final WorkoutHistoryEntry entry;
  final HistoryMonthStats stats;

  @override
  Widget build(BuildContext context) {
    final day = entry.session.startedAt.toLocal().day;

    return HistorySessionCard(
      entry: entry,
      hasRecord: stats.hasRecord(day),
      onTap: () => context.push(AppRoutes.workoutDetail(entry.session.id)),
    );
  }
}
