import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Le haut de la carte de série : « Série 3 », l'objectif du programme
/// dessous s'il y en a un, et la pastille « À saisir ».
class SetEntryHeading extends StatelessWidget {
  const SetEntryHeading({
    required this.setNumber,
    required this.objective,
    super.key,
  });

  final int setNumber;
  final String? objective;

  @override
  Widget build(BuildContext context) {
    final objective = this.objective;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Série ${formatThousands(setNumber)}',
                style: AppTypography.title.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              if (objective != null)
                Text(
                  objective,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const AppPill(label: 'À saisir'),
      ],
    );
  }
}

/// « ⏱ Dernière série : 80 kg × 8 reps », sous les champs.
class PreviousSetLine extends StatelessWidget {
  const PreviousSetLine({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ExcludeSemantics(
          child: Icon(
            AppIcons.history,
            size: 20,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
