import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Une réponse de quiz : sa lettre, son texte, et l'état qu'elle a pris.
///
/// Le rond à lettre est ce qui la fait lire comme un BOUTON plutôt que comme
/// une ligne de liste — sans lui, trois rectangles bordés ressemblaient à un
/// tableau qu'on ne pense pas à toucher.
class QuizChoice extends StatelessWidget {
  const QuizChoice({
    required this.letter,
    required this.label,
    required this.picked,
    required this.correct,
    required this.answered,
    this.onTap,
    super.key,
  });

  final String letter;
  final String label;

  /// C'est CE choix qui a été fait.
  final bool picked;

  /// C'est la bonne réponse.
  final bool correct;

  /// Une réponse a été donnée, quelle qu'elle soit.
  final bool answered;

  final VoidCallback? onTap;

  static const double _chipSize = 24;

  @override
  Widget build(BuildContext context) {
    // Deux choses se colorent une fois répondu : ce qui a été CHOISI, et ce
    // qui était JUSTE. Montrer la bonne réponse sans montrer celle qui a été
    // donnée laisserait croire à une réussite après une erreur ; ne montrer
    // que l'erreur n'apprendrait rien. La coche, elle, ne va qu'au choix
    // fait — c'est elle qui dit « c'est toi qui as répondu ça ».
    final tone = correct && answered
        ? AppColors.success
        : picked
            ? AppColors.danger
            : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        button: onTap != null,
        selected: picked,
        label: '$letter. $label',
        onTap: onTap,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppMotion.tap,
              curve: AppMotion.standard,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gapRow,
                vertical: AppSpacing.sm + 1,
              ),
              decoration: BoxDecoration(
                color: tone == null
                    ? AppColors.quizChoiceFill
                    : tone.withValues(alpha: 0.10),
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: tone ?? AppColors.quizChoiceBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: _chipSize,
                    height: _chipSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                      border: tone == null
                          ? Border.all(color: AppColors.quizLetterBorder)
                          : null,
                    ),
                    child: Text(
                      letter,
                      style: AppTypography.labelMono.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: tone == null
                            ? AppColors.darkTextTertiary
                            : AppColors.darkBackground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.body.copyWith(
                        fontSize: 14,
                        fontWeight: picked ? FontWeight.w600 : FontWeight.w400,
                        color: answered && !picked
                            ? AppColors.darkTextTertiary
                            : AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  if (picked) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(AppIcons.checkCircle, size: 18, color: tone),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
