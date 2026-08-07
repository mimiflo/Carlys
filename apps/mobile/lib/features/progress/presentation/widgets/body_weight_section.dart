import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';
import 'add_weight_sheet.dart';

/// Suivi du poids corporel : courbe, dernières mesures, ajout et suppression.
class BodyWeightSection extends ConsumerWidget {
  const BodyWeightSection({super.key});

  static const int _recentCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(bodyWeightMetricsProvider);

    return metrics.when(
      loading: () => const AppLoadingIndicator(label: 'Chargement'),
      error: (_, __) => AppErrorState(
        title: 'Mesures indisponibles',
        onRetry: () => ref.invalidate(bodyWeightMetricsProvider),
      ),
      data: (entries) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            const AppEmptyState(
              title: 'Aucune mesure enregistrée',
              message: 'Ajoutez votre poids pour suivre son évolution.',
              icon: AppIcons.bodyMetrics,
            )
          else ...[
            _WeightChart(entries: entries),
            const SizedBox(height: AppSpacing.sm),
            for (final entry in entries.reversed.take(_recentCount))
              _WeightTile(entry: entry),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Ajouter mon poids',
            icon: AppIcons.add,
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            onPressed: () => _addWeight(context, ref, entries),
          ),
        ],
      ),
    );
  }

  Future<void> _addWeight(
    BuildContext context,
    WidgetRef ref,
    List<BodyMetricEntry> entries,
  ) async {
    final valueKg = await showAddWeightSheet(
      context,
      initialKg: entries.isEmpty ? null : entries.last.value,
    );
    if (valueKg == null) {
      return;
    }
    try {
      await ref.read(bodyMetricActionsProvider).addWeight(valueKg);
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’enregistrer la mesure.')),
        );
      }
    }
  }
}

class _WeightTile extends ConsumerWidget {
  const _WeightTile({required this.entry});

  final BodyMetricEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = _formatDate(entry.measuredAt);

    return Row(
      children: [
        Expanded(child: Text(date, style: theme.textTheme.bodyLarge)),
        Text(
          '${_formatWeight(entry.value)} kg',
          style: AppTypography.metric.copyWith(
            fontSize: 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
        IconButton(
          onPressed: () => _remove(context, ref),
          tooltip: 'Supprimer la mesure du $date',
          icon: const Icon(AppIcons.delete, size: 20),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(bodyMetricActionsProvider).remove(entry.id);
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de supprimer la mesure.')),
        );
      }
    }
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries});

  final List<BodyMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = entries.map((entry) => entry.value);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Semantics(
        label: 'Évolution du poids corporel',
        // Isole le rendu du graphique : ses repeints ne redessinent pas l'écran.
        child: RepaintBoundary(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LineChart(
              LineChartData(
                minY: minValue - 1,
                maxY: maxValue + 1,
                lineTouchData: LineTouchData(enabled: false),
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < entries.length; i++)
                        FlSpot(i.toDouble(), entries[i].value),
                    ],
                    isCurved: true,
                    color: scheme.primary,
                    barWidth: AppSpacing.xxs / 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatWeight(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _formatDate(DateTime utc) {
  final local = utc.toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year}';
}
