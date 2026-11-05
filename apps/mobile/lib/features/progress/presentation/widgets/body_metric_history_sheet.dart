import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../providers/progress_providers.dart';
import 'body_metric_chart.dart';
import 'body_metric_gestures.dart';
import 'body_metric_latest.dart';
import 'body_metric_row.dart';

/// TOUTES les mesures d'un type, et donc toutes les mesures corrigeables.
///
/// La page n'en montrait que les trois dernières. Une pesée d'il y a deux
/// semaines était enregistrée, tracée dans la courbe, et impossible à
/// corriger ou à supprimer depuis l'application, alors que l'API sait le
/// faire depuis le début : `PATCH` et `DELETE /body-metrics/:id` existent,
/// sont testés, et n'avaient simplement aucune porte.
///
/// La même feuille sert le poids et chaque mensuration ([kind]). Pour une
/// mensuration, elle porte en plus la courbe de la zone et l'ajout à CETTE
/// zone : la section n'en montre que la dernière valeur, c'est ici que
/// l'histoire se lit. Le poids a déjà sa courbe sur la page.
///
/// Elle lit le provider plutôt que de recevoir une liste figée : corriger ou
/// supprimer une mesure depuis la feuille doit se voir DANS la feuille, sans
/// la refermer.
Future<void> showBodyMetricHistory(
  BuildContext context, {
  BodyMetricKind kind = BodyMetricKind.weightKg,
}) {
  return showAppSheet<void>(
    context,
    style: AppSheetStyle.picker,
    builder: (_) => _BodyMetricHistorySheet(kind: kind),
  );
}

class _BodyMetricHistorySheet extends ConsumerWidget {
  const _BodyMetricHistorySheet({required this.kind});

  final BodyMetricKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(bodyMetricsOfKindProvider(kind));
    // Du plus récent au plus ancien : on corrige d'abord ce qu'on vient de
    // saisir.
    final recentes = entries.reversed.toList();
    final zone = kind.isMeasurement;
    final titre = zone
        ? '${kind.label} · ${recentes.length} '
              '${recentes.length > 1 ? 'mesures' : 'mesure'}'
        : 'Mes ${recentes.length} mesures';

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
            AppSectionHeader(
              title: titre,
              trailing: zone ? 'Ajouter' : null,
              trailingIcon: zone ? AppIcons.add : null,
              trailingTone: AppSectionTrailingTone.primary,
              onTrailingTap: zone
                  ? () => addBodyMeasurement(
                      context,
                      ref,
                      initialKind: kind,
                      initialValue: entries.isEmpty ? null : entries.last.value,
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (recentes.isEmpty)
              AppEmptyState(
                title: 'Aucune mesure enregistrée',
                message: zone
                    ? 'Ajoute un tour pour suivre son évolution.'
                    : 'Ajoute ton poids pour suivre son évolution.',
                icon: zone ? AppIcons.bodyMeasurements : AppIcons.bodyMetrics,
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: recentes.length + (zone ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    if (zone && index == 0) {
                      return _ZoneCurve(entries: entries);
                    }
                    final rang = zone ? index - 1 : index;
                    return BodyMetricRow(
                      entry: recentes[rang],
                      isLatest: rang == 0,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La courbe du poids, reprise pour la zone ; avec une seule mesure, la
/// dernière valeur seule, comme la section du poids.
class _ZoneCurve extends StatelessWidget {
  const _ZoneCurve({required this.entries});

  final List<BodyMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: entries.length < BodyMetricChart.minimumEntries
          ? BodyMetricFirstMeasure(entry: entries.last)
          : BodyMetricChart(entries: entries),
    );
  }
}
