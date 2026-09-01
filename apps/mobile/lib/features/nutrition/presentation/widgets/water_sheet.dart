import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/water_controllers.dart';

/// Feuille « Hydratation » : le total du jour, deux gestes pour l'augmenter,
/// un pour revenir en arrière.
///
/// Une feuille plutôt qu'un tapotement direct sur la cellule : ajouter de
/// l'eau par mégarde depuis l'accueil serait pénible à défaire, et le retour
/// arrière doit être aussi accessible que l'ajout — on se trompe de verre
/// aussi souvent qu'on en boit un.
Future<void> showWaterSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _WaterForm());
}

class _WaterForm extends ConsumerWidget {
  const _WaterForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consumed = ref.watch(consumedWaterTodayProvider).valueOrNull ?? 0;
    final target = ref.watch(metabolismTargetWaterMlProvider).valueOrNull;
    final actions = ref.read(waterActionsProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hydratation',
            style: AppTypography.subheading
                .copyWith(color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            target == null
                ? 'Compté sur cet appareil, remis à zéro chaque nuit.'
                : 'Objectif du jour : ${formatDecimal(target / 1000)} L.',
            style:
                AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatDecimal(consumed / 1000),
                style: AppTypography.metricXL
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'L',
                style: AppTypography.labelMono
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '+ 25 cl',
                  icon: AppIcons.water,
                  onPressed: () => actions.add(waterGlassMl),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: '+ 50 cl',
                  icon: AppIcons.water,
                  onPressed: () => actions.add(waterBottleMl),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Retirer un verre',
              variant: AppButtonVariant.ghost,
              // Désactivé à zéro plutôt que borné en silence : un bouton qui
              // ne fait rien quand on le presse est pire qu'un bouton éteint.
              onPressed:
                  consumed == 0 ? null : () => actions.add(-waterGlassMl),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
