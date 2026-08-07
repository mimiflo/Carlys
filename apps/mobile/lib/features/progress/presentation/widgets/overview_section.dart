import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';

/// Statistiques de la période : sélecteur, cartes de synthèse, volume.
class OverviewSection extends ConsumerWidget {
  const OverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(progressPeriodProvider);
    final overview = ref.watch(progressOverviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ProgressPeriod>(
          segments: [
            for (final value in ProgressPeriod.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {period},
          onSelectionChanged: (selection) =>
              ref.read(progressPeriodProvider.notifier).state = selection.first,
        ),
        const SizedBox(height: AppSpacing.md),
        overview.when(
          loading: () => const AppLoadingIndicator(label: 'Chargement'),
          error: (_, __) => AppErrorState(
            title: 'Statistiques indisponibles',
            message: 'Vérifiez votre connexion puis réessayez.',
            onRetry: () => ref.invalidate(progressOverviewProvider),
          ),
          data: (data) => _OverviewContent(overview: data),
        ),
      ],
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.overview});

  final ProgressOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Séances',
                value: '${overview.sessionsCount}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(label: 'Séries', value: '${overview.setsCount}'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Volume',
                value: '${overview.totalVolumeKg.round()} kg',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: 'Durée',
                value: _formatDuration(overview.totalDurationSeconds),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (overview.points.isEmpty)
          const AppEmptyState(
            title: 'Aucune séance sur la période',
            message: 'Terminez une séance pour voir votre volume ici.',
            icon: AppIcons.progress,
          )
        else
          _VolumeChart(points: overview.points),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      semanticLabel: '$label : $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.metric.copyWith(
              fontSize: 24,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxVolume = points.fold<double>(
      1,
      (max, point) => point.volumeKg > max ? point.volumeKg : max,
    );

    return AppCard(
      child: Semantics(
        label: 'Volume soulevé par intervalle sur la période',
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: BarChart(
            BarChartData(
              maxY: maxVolume * 1.15,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(enabled: false),
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].volumeKg,
                        color: scheme.primary,
                        width: AppSpacing.xs,
                        borderRadius: AppRadius.xsAll,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    return '$minutes min';
  }
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
}
