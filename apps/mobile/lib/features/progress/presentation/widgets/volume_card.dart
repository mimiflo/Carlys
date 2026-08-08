import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../utils/progress_stats.dart';

/// Hauteur du graphe en barres et géométrie des barres (maquette).
const double _chartHeight = 104;
const double _barGap = 6;
const double _barRadius = 5;
const double _minBarHeight = 6;

/// Largeur d'une barre quand la période en compte peu : sans plafond, deux
/// intervalles produiraient deux pavés au lieu d'un graphe.
const double _maxBarWidth = 26;

/// Carte de volume : total de la période, tendance, graphe en barres et
/// repères temporels — tout est dérivé des points réels de l'API.
class VolumeCard extends StatelessWidget {
  const VolumeCard({required this.overview, super.key});

  final ProgressOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    final volume = formatVolume(overview.totalVolumeKg);
    final trend = volumeTrendPercent(overview.points);
    final labels = volumeAxisLabels(overview.points, overview.period);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardMainAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionLabel(
                      volumeLabel(overview.period),
                      color: AppColors.darkTextTertiary,
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text: volume.value,
                        style: AppTypography.metricL.copyWith(
                          fontSize: 30,
                          letterSpacing: -1.2,
                          color: AppColors.darkTextPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: ' ${volume.unit}',
                            style: AppTypography.metricS.copyWith(
                              fontSize: 15,
                              color: AppColors.darkTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (trend != null) _TrendPill(percent: trend),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _VolumeBars(points: overview.points),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final label in labels)
                  Text(
                    label,
                    style: AppTypography.labelMono.copyWith(
                      fontSize: 9,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tendance du dernier intervalle : accent à la hausse, neutre à la baisse
/// (le design system n'expose pas d'icône de tendance descendante).
class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final rising = percent >= 0;
    final sign = rising ? '+' : '';

    return AppPill(
      label: '$sign${formatThousands(percent)}%',
      mono: true,
      tone: rising ? AppPillTone.accent : AppPillTone.neutral,
      icon: rising ? AppIcons.trendingUp : null,
    );
  }
}

/// Barres du volume : violet de plus en plus opaque avec la récence, le
/// dernier intervalle en accent.
class _VolumeBars extends StatelessWidget {
  const _VolumeBars({required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxVolume = points.fold<double>(
      0,
      (max, point) => point.volumeKg > max ? point.volumeKg : max,
    );

    return Semantics(
      label: 'Volume soulevé par intervalle',
      child: SizedBox(
        height: _chartHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < points.length; index++) ...[
              if (index > 0) const SizedBox(width: _barGap),
              Expanded(
                child: _VolumeBar(
                  fraction:
                      maxVolume <= 0 ? 0 : points[index].volumeKg / maxVolume,
                  recency: points.length < 2
                      ? 1
                      : index / (points.length - 1).toDouble(),
                  isLatest: index == points.length - 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolumeBar extends StatelessWidget {
  const _VolumeBar({
    required this.fraction,
    required this.recency,
    required this.isLatest,
  });

  final double fraction;

  /// 0 pour l'intervalle le plus ancien, 1 pour le plus récent.
  final double recency;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final height = _minBarHeight +
        (_chartHeight - _minBarHeight) * fraction.clamp(0.0, 1.0);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        constraints: const BoxConstraints(maxWidth: _maxBarWidth),
        decoration: BoxDecoration(
          color: isLatest
              ? AppColors.accent
              : AppColors.primary
                  .withValues(alpha: 0.35 + 0.55 * recency.clamp(0.0, 1.0)),
          borderRadius: BorderRadius.circular(_barRadius),
        ),
      ),
    );
  }
}
