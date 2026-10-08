import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../providers/progress_providers.dart';
import 'add_weight_action.dart';
import 'body_weight_chart.dart';
import 'body_weight_history_sheet.dart';
import 'body_weight_latest.dart';

/// Suivi du poids corporel : la dernière mesure et sa courbe ; l'ajout dans
/// l'en-tête, la correction et le retrait dans la feuille des mesures.
class BodyWeightSection extends ConsumerWidget {
  const BodyWeightSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(bodyWeightMetricsProvider);
    final entries = metrics.valueOrNull ?? const <BodyMetricEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Poids corporel',
          trailing: 'Ajouter',
          trailingIcon: AppIcons.add,
          trailingTone: AppSectionTrailingTone.primary,
          onTrailingTap: () => addBodyWeight(
            context,
            ref,
            initialKg: entries.isEmpty ? null : entries.last.value,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        metrics.when(
          loading: () => const AppLoadingIndicator(label: 'Chargement'),
          error: (_, __) => AppErrorState(
            title: 'Mesures indisponibles',
            message: AppErrorState.retryConnectionMessage,
            onRetry: () => ref.invalidate(bodyWeightMetricsProvider),
          ),
          data: (entries) => _BodyWeightContent(entries: entries),
        ),
      ],
    );
  }
}

/// Trois états, selon ce qu'il y a à montrer : rien, une mesure, une courbe.
class _BodyWeightContent extends StatelessWidget {
  const _BodyWeightContent({required this.entries});

  /// Du plus ancien au plus récent, comme le renvoie le repository.
  final List<BodyMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppEmptyState(
        title: 'Aucune mesure enregistrée',
        message: 'Ajoute ton poids pour suivre son évolution.',
        icon: AppIcons.bodyMetrics,
      );
    }

    // La même carte sous la courbe et sous la première mesure : l'arrivée
    // de la courbe ne change pas le décor.
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Une courbe demande deux points : avant, la mesure est un fait
          // qui se lit seul, pas un graphique vide.
          if (entries.length < BodyWeightChart.minimumEntries)
            BodyWeightFirstMeasure(entry: entries.last)
          else
            BodyWeightChart(entries: entries),
          const SizedBox(height: AppSpacing.sm),
          // L'historique — et la correction ou le retrait d'une mesure — vit
          // dans sa feuille.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showBodyWeightHistory(context),
              iconAlignment: IconAlignment.end,
              icon: const Icon(AppIcons.chevronRight),
              label: const Text('Voir mes mesures'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                padding: EdgeInsets.zero,
                textStyle: AppTypography.subheading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
