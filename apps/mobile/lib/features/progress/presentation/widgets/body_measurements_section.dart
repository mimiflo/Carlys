import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../providers/progress_providers.dart';
import '../utils/progress_stats.dart';
import 'body_metric_gestures.dart';
import 'body_metric_history_sheet.dart';

/// Les MENSURATIONS, sous le poids : une ligne par zone déjà mesurée — sa
/// dernière valeur et son écart depuis la plus ancienne des mesures
/// chargées (90 au plus, voir `measurementTrend`) —, l'ajout dans
/// l'en-tête, l'histoire de la zone (courbe, correction, retrait) dans sa
/// feuille.
///
/// Une zone jamais mesurée n'a pas de ligne : sept lignes vides diraient
/// sept fois « rien ». Tant qu'aucune ne l'est, un seul état vide invite à
/// commencer.
class BodyMeasurementsSection extends ConsumerWidget {
  const BodyMeasurementsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements = ref.watch(bodyMeasurementsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Mensurations',
          trailing: 'Ajouter',
          trailingIcon: AppIcons.add,
          trailingTone: AppSectionTrailingTone.primary,
          onTrailingTap: () => addBodyMeasurement(context, ref),
        ),
        const SizedBox(height: AppSpacing.sm),
        measurements.when(
          loading: () =>
              const AppLoadingIndicator(label: 'Chargement des mensurations'),
          // Hors ligne compris : les mesures se lisent sur le serveur, et
          // l'état d'erreur dit de retrouver la connexion.
          error: (_, __) => AppErrorState(
            title: 'Mensurations indisponibles',
            message: AppErrorState.retryConnectionMessage,
            onRetry: () => ref.invalidate(bodyMeasurementsProvider),
          ),
          data: (byZone) => _MeasurementsContent(byZone: byZone),
        ),
      ],
    );
  }
}

class _MeasurementsContent extends ConsumerWidget {
  const _MeasurementsContent({required this.byZone});

  final Map<BodyMetricKind, List<BodyMetricEntry>> byZone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = [
      for (final kind in BodyMetricKind.measurements)
        if (byZone[kind]?.isNotEmpty ?? false) kind,
    ];
    if (zones.isEmpty) {
      return AppEmptyState(
        title: 'Aucune mensuration',
        message:
            'Taille, hanches, bras… Un tour de mètre ruban, et tu suis ce '
            'que la balance ne dit pas.',
        icon: AppIcons.bodyMeasurements,
        actionLabel: 'Prendre une mesure',
        onAction: () => addBodyMeasurement(context, ref),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, kind) in zones.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.sm),
          _ZoneRow(entries: byZone[kind]!),
        ],
      ],
    );
  }
}

/// Une zone : son nom, son écart depuis la première mesure, sa dernière
/// valeur. Toucher la ligne ouvre son histoire.
class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.entries});

  /// Du plus ancien au plus récent, non vide.
  final List<BodyMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    final latest = entries.last;
    final kind = latest.kind;
    void ouvrir() => showBodyMetricHistory(context, kind: kind);
    return Semantics(
      button: true,
      label:
          '${kind.label} : ${formatDecimal(latest.value)} ${kind.spokenUnit}, '
          '${measurementTrend(entries)}. Voir l’historique.',
      // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
      onTap: ouvrir,
      excludeSemantics: true,
      child: AppListRow(
        title: kind.label,
        subtitle: measurementTrend(entries),
        leading: AppIcons.bodyMeasurements,
        trailingText: '${formatDecimal(latest.value)} cm',
        onTap: ouvrir,
      ),
    );
  }
}
