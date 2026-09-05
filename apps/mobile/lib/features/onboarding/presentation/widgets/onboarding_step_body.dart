import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Bloc bas d'une étape : thème de la question, question, sous-titre, puis
/// les cartes de réponse.
class OnboardingStepBody extends StatelessWidget {
  const OnboardingStepBody({
    required this.label,
    required this.question,
    required this.subtitle,
    required this.options,
    super.key,
  });

  final String label;
  final String question;
  final String subtitle;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSectionLabel(label),
        const SizedBox(height: AppSpacing.gapTile),
        Text(
          question,
          style: AppTypography.display.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.gapTile),
        Text(
          subtitle,
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.gapTile),
          options[i],
        ],
      ],
    );
  }
}
