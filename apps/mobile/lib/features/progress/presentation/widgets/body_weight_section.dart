import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';
import 'add_weight_action.dart';
import 'body_weight_chart.dart';
import 'body_weight_history_sheet.dart';
import 'body_weight_latest.dart';
import 'body_weight_row.dart';

/// Suivi du poids corporel : courbe, dernières mesures, ajout et suppression.
///
/// Même grammaire visuelle que les records : carte de tête, puis lignes.
class BodyWeightSection extends ConsumerWidget {
  const BodyWeightSection({super.key});

  /// Mesures listées SOUS LA COURBE. Les autres ne sont pas perdues : la
  /// feuille d'historique les ouvre toutes, et c'est elle qui rend chacune
  /// corrigeable. Trois ici est un choix de mise en page, plus une limite.
  static const int recentCount = 3;

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

    final recent = entries.reversed
        .take(BodyWeightSection.recentCount)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Une courbe demande deux points : avant, la mesure est un fait qui
        // se lit seul, pas un graphique vide.
        if (entries.length < BodyWeightChart.minimumEntries)
          BodyWeightFirstMeasure(entry: entries.last)
        else
          BodyWeightChart(entries: entries),
        for (final (index, entry) in recent.indexed) ...[
          const SizedBox(height: AppSpacing.sm),
          WeightRow(entry: entry, isLatest: index == 0),
        ],
        if (entries.length > BodyWeightSection.recentCount) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (context) => AppPill(
                label: 'Voir mes ${entries.length} mesures',
                icon: AppIcons.history,
                onTap: () => showBodyWeightHistory(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
