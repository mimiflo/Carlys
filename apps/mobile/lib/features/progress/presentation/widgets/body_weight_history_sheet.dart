import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';
import 'body_weight_row.dart';

/// TOUTES les mesures, et donc toutes les mesures corrigeables.
///
/// La page n'en montrait que les trois dernières. Une pesée d'il y a deux
/// semaines était enregistrée, tracée dans la courbe, et impossible à
/// corriger ou à supprimer depuis l'application, alors que l'API sait le
/// faire depuis le début : `PATCH` et `DELETE /body-metrics/:id` existent,
/// sont testés, et n'avaient simplement aucune porte.
///
/// Elle lit le provider plutôt que de recevoir une liste figée : corriger ou
/// supprimer une mesure depuis la feuille doit se voir DANS la feuille, sans
/// la refermer.
Future<void> showBodyWeightHistory(BuildContext context) {
  return showAppSheet<void>(
    context,
    style: AppSheetStyle.picker,
    builder: (_) => const _BodyWeightHistorySheet(),
  );
}

class _BodyWeightHistorySheet extends ConsumerWidget {
  const _BodyWeightHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(bodyWeightMetricsProvider).valueOrNull ??
        const <BodyMetricEntry>[];
    // Du plus récent au plus ancien : on corrige d'abord ce qu'on vient de
    // saisir.
    final recentes = entries.reversed.toList();

    // Les marges système (haut ET bas) sont déjà prises par `showAppSheet`.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(title: 'Mes ${recentes.length} mesures'),
            const SizedBox(height: AppSpacing.sm),
            if (recentes.isEmpty)
              const AppEmptyState(
                title: 'Aucune mesure enregistrée',
                message: 'Ajoute ton poids pour suivre son évolution.',
                icon: AppIcons.bodyMetrics,
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: recentes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) =>
                      WeightRow(entry: recentes[index], isLatest: index == 0),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
