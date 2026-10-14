import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Bloc bas d'une étape : thème de la question, question, sous-titre, puis
/// les cartes de réponse.
///
/// [centered] est la mise en page de l'étape d'identité (maquette d'octobre
/// 2026) : la question, sa ligne mono dessous, le sous-titre violet, tout
/// centré, et une [footnote] sous les cartes.
class OnboardingStepBody extends StatelessWidget {
  const OnboardingStepBody({
    required this.label,
    required this.question,
    required this.subtitle,
    required this.options,
    this.centered = false,
    this.footnote,
    super.key,
  });

  final String label;
  final String question;
  final String subtitle;
  final List<Widget> options;
  final bool centered;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final align = centered ? TextAlign.center : TextAlign.start;
    final questionText = Text(
      question,
      textAlign: align,
      style: AppTypography.display.copyWith(color: AppColors.darkTextPrimary),
    );
    final labelText = centered
        ? Center(child: AppSectionLabel(label))
        : AppSectionLabel(label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (centered) ...[
          questionText,
          const SizedBox(height: AppSpacing.xs),
          labelText,
        ] else ...[
          labelText,
          const SizedBox(height: AppSpacing.gapTile),
          questionText,
        ],
        const SizedBox(height: AppSpacing.gapTile),
        Text(
          subtitle,
          textAlign: align,
          style: centered
              ? AppTypography.bodyLarge.copyWith(color: AppColors.primaryLight)
              : AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.gapTile),
          options[i],
        ],
        if (footnote case final footnote?) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            footnote,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
