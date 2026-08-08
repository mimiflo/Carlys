import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';
import 'add_weight_sheet.dart';
import 'body_weight_chart.dart';

/// Suivi du poids corporel : courbe, dernières mesures, ajout et suppression.
///
/// Même grammaire visuelle que les records : carte de tête, puis lignes.
class BodyWeightSection extends ConsumerWidget {
  const BodyWeightSection({super.key});

  /// Mesures listées sous la courbe (les plus récentes).
  static const int recentCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(bodyWeightMetricsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Poids corporel',
          trailing: 'Ajouter',
          trailingIcon: AppIcons.add,
          trailingTone: AppSectionTrailingTone.primary,
          onTrailingTap: () => _addWeight(
            context,
            ref,
            metrics.valueOrNull ?? const [],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        metrics.when(
          loading: () => const AppLoadingIndicator(label: 'Chargement'),
          error: (_, __) => AppErrorState(
            title: 'Mesures indisponibles',
            message: 'Vérifiez votre connexion puis réessayez.',
            onRetry: () => ref.invalidate(bodyWeightMetricsProvider),
          ),
          data: (entries) => _BodyWeightContent(entries: entries),
        ),
      ],
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

class _BodyWeightContent extends StatelessWidget {
  const _BodyWeightContent({required this.entries});

  /// Du plus ancien au plus récent, comme le renvoie le repository.
  final List<BodyMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppEmptyState(
        title: 'Aucune mesure enregistrée',
        message: 'Ajoutez votre poids pour suivre son évolution.',
        icon: AppIcons.bodyMetrics,
      );
    }

    final recent =
        entries.reversed.take(BodyWeightSection.recentCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BodyWeightChart(entries: entries),
        for (final (index, entry) in recent.indexed) ...[
          const SizedBox(height: AppSpacing.sm),
          _WeightRow(entry: entry, isLatest: index == 0),
        ],
      ],
    );
  }
}

/// Ligne de mesure : date en mono, valeur à droite, suppression au bout.
class _WeightRow extends ConsumerWidget {
  const _WeightRow({required this.entry, required this.isLatest});

  final BodyMetricEntry entry;
  final bool isLatest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = formatShortDateMono(entry.measuredAt.toLocal());
    final value = formatDecimal(entry.value);

    return Semantics(
      label: 'Poids du $date : $value kg',
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.statTileAll,
          border:
              Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.bodyMetrics,
              size: 22,
              color: isLatest ? AppColors.accent : AppColors.primaryLight,
            ),
            const SizedBox(width: AppSpacing.gapRow),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metricS.copyWith(
                      fontSize: 13,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatRelativeDayMono(entry.measuredAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMono.copyWith(
                      fontSize: 11,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text.rich(
              TextSpan(
                text: value,
                style: AppTypography.metricS.copyWith(
                  fontSize: 15,
                  color: AppColors.darkTextPrimary,
                ),
                children: [
                  TextSpan(
                    text: 'kg',
                    style: AppTypography.metricS.copyWith(
                      fontSize: 11,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _remove(context, ref),
              tooltip: 'Supprimer la mesure du $date',
              icon: const Icon(
                AppIcons.delete,
                size: 20,
                color: AppColors.darkTextTertiary,
              ),
            ),
          ],
        ),
      ),
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
