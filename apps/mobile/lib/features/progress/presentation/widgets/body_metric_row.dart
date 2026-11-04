import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../providers/progress_providers.dart';
import 'body_metric_gestures.dart';

/// Ligne de mesure : date en mono, valeur à droite, correction et suppression.
///
/// Une seule ligne pour le poids ET les mensurations, dans la feuille
/// d'historique de chacun : les recopier aurait fait diverger la
/// confirmation de suppression, qui est justement ce qu'on ne veut pas voir
/// diverger. Ce qui change d'un type à l'autre — l'unité, l'icône, la
/// feuille de correction, la conséquence d'une suppression — se lit dans
/// [BodyMetricEntry.kind].
class BodyMetricRow extends ConsumerWidget {
  const BodyMetricRow({required this.entry, required this.isLatest, super.key});

  final BodyMetricEntry entry;

  /// La plus récente porte l'accent. Pour le poids, c'est aussi elle qui
  /// nourrit le rapport métabolique.
  final bool isLatest;

  bool get _feedsMetabolism =>
      isLatest && entry.kind == BodyMetricKind.weightKg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = formatShortDateMono(entry.measuredAt.toLocal());
    final value = formatDecimal(entry.value);

    return Semantics(
      label: '${entry.kind.label} du $date : $value ${entry.kind.unit}',
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
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.darkBorder),
          ),
        ),
        child: Row(
          children: [
            Icon(
              entry.kind.isMeasurement
                  ? AppIcons.bodyMeasurements
                  : AppIcons.bodyMetrics,
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
                    style: AppTypography.resized(
                      AppTypography.metricS,
                      13,
                    ).copyWith(color: AppColors.darkTextPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatRelativeDayMono(entry.measuredAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.resized(
                      AppTypography.labelMono,
                      11,
                    ).copyWith(color: AppColors.darkTextTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text.rich(
              TextSpan(
                text: value,
                style: AppTypography.resized(
                  AppTypography.metricS,
                  15,
                ).copyWith(color: AppColors.darkTextPrimary),
                children: [
                  TextSpan(
                    text: entry.kind.unit,
                    style: AppTypography.resized(
                      AppTypography.metricS,
                      11,
                    ).copyWith(color: AppColors.darkTextTertiary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => correctBodyMetric(context, ref, entry),
              tooltip: 'Corriger la mesure du $date',
              icon: const Icon(
                AppIcons.editOutline,
                size: 20,
                color: AppColors.darkTextTertiary,
              ),
            ),
            IconButton(
              onPressed: () => _remove(context, ref, date),
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

  /// Supprimer une pesée n'est pas anodin : la plus récente nourrit le
  /// rapport métabolique, donc l'effacer DÉPLACE le métabolisme de base, la
  /// cible calorique et les macros. La correction prévient, parce qu'on y
  /// voit la valeur qu'on remplace ; la suppression, elle, partait d'un seul
  /// tapotement, sans un mot et sans retour possible.
  Future<void> _remove(BuildContext context, WidgetRef ref, String date) async {
    final confirme = await showAppConfirm(
      context,
      title: 'Supprimer la mesure du $date ?',
      message: _feedsMetabolism
          ? 'C’est ta mesure la plus récente : ton métabolisme de base, '
                'ta cible calorique et tes macros seront recalculés sur '
                'la précédente.'
          : 'Elle disparaîtra de ta courbe. Tes séances et tes records '
                'ne bougent pas.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirme) {
      return;
    }

    try {
      await ref.read(bodyMetricActionsProvider).remove(entry);
    } on Exception {
      if (context.mounted) {
        AppNotices.of(
          context,
        ).show('Impossible de supprimer la mesure.', tone: AppNoticeTone.error);
      }
    }
  }
}
