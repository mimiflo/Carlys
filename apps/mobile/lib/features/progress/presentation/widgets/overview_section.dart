import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';

/// Statistiques de la période (2f) : sélecteur en pastilles, carte de
/// volume avec graphe en barres, grille de tuiles.
class OverviewSection extends ConsumerWidget {
  const OverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(progressPeriodProvider);
    final overview = ref.watch(progressOverviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final value in ProgressPeriod.values) ...[
              AppPill(
                label: value.label,
                selected: period == value,
                onTap: () =>
                    ref.read(progressPeriodProvider.notifier).state = value,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ],
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
        if (overview.points.isEmpty)
          const AppEmptyState(
            title: 'Aucune séance sur la période',
            message: 'Terminez une séance pour voir votre volume ici.',
            icon: AppIcons.progress,
          )
        else
          _VolumeCard(overview: overview),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Séances',
                value: '${overview.sessionsCount}',
              ),
            ),
            const SizedBox(width: AppSpacing.gapTile),
            Expanded(
              child: AppStatTile(
                label: 'Séries',
                value: '${overview.setsCount}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gapTile),
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Volume',
                value: '${overview.totalVolumeKg.round()}',
                unit: ' kg',
              ),
            ),
            const SizedBox(width: AppSpacing.gapTile),
            Expanded(
              child: AppStatTile(
                label: 'Durée',
                value: _formatDuration(overview.totalDurationSeconds),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Carte de volume : label mono, total en grand, barres primary — la
/// dernière période en accent.
class _VolumeCard extends StatelessWidget {
  const _VolumeCard({required this.overview});

  final ProgressOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    final points = overview.points;
    final maxVolume = points.fold<double>(
      1,
      (max, point) => point.volumeKg > max ? point.volumeKg : max,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardMainAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionLabel('Volume soulevé'),
          const SizedBox(height: 8),
          Text(
            '${overview.totalVolumeKg.round()} kg',
            style: AppTypography.metricL
                .copyWith(color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: 'Volume soulevé par intervalle sur la période',
            // Isole le rendu du graphique : ses repeints restent locaux.
            child: RepaintBoundary(
              child: AspectRatio(
                aspectRatio: 16 / 7,
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
                              color: i == points.length - 1
                                  ? AppColors.accent
                                  : AppColors.primaryFill,
                              width: 8,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
