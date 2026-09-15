import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';
import 'add_weight_action.dart';

/// Ligne de mesure : date en mono, valeur à droite, correction et suppression.
///
/// Publique parce qu'elle sert à DEUX endroits : les trois dernières mesures
/// sous la courbe, et la liste complète de la feuille d'historique. Les
/// recopier aurait fait diverger la confirmation de suppression, qui est
/// justement ce qu'on ne veut pas voir diverger.
class WeightRow extends ConsumerWidget {
  const WeightRow({required this.entry, required this.isLatest, super.key});

  final BodyMetricEntry entry;

  /// La plus récente porte l'accent : c'est elle qui nourrit le rapport
  /// métabolique.
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
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.darkBorder),
          ),
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
                    text: 'kg',
                    style: AppTypography.resized(
                      AppTypography.metricS,
                      11,
                    ).copyWith(color: AppColors.darkTextTertiary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => correctBodyWeight(
                context,
                ref,
                metricId: entry.id,
                valueKg: entry.value,
                measuredAt: entry.measuredAt,
              ),
              tooltip: 'Corriger la mesure du $date',
              icon: const Icon(
                Icons.edit_outlined,
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
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer la mesure du $date ?'),
        content: Text(
          isLatest
              ? 'C’est ta mesure la plus récente : ton métabolisme de base, '
                    'ta cible calorique et tes macros seront recalculés sur '
                    'la précédente.'
              : 'Elle disparaîtra de ta courbe. Tes séances et tes records '
                    'ne bougent pas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: 'Supprimer',
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirme != true) {
      return;
    }

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
