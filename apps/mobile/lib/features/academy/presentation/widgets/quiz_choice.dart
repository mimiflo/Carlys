import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Une réponse de quiz (maquette Academy d'octobre 2026) : un rond à cocher
/// et son texte, sur une ligne que la carte sépare de la suivante d'un
/// filet. La lettre ne se voit plus ; le lecteur d'écran la dit encore.
class QuizChoice extends StatelessWidget {
  const QuizChoice({
    required this.letter,
    required this.label,
    required this.picked,
    required this.correct,
    required this.answered,
    this.pending = false,
    this.boxed = false,
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

  /// Coché, pas encore validé : le rond prend le violet de la marque.
  final bool pending;

  /// Une réponse encadrée (dans une leçon) plutôt qu'une ligne nue.
  final bool boxed;

  final VoidCallback? onTap;

  static const double _radioSize = 22;
  static const double _pendingDot = 10;
  static const double _ringWidth = 2;

  @override
  Widget build(BuildContext context) {
    // Deux choses se colorent une fois répondu : ce qui a été CHOISI, et ce
    // qui était JUSTE. Montrer la bonne réponse sans montrer celle qui a été
    // donnée laisserait croire à une réussite après une erreur ; ne montrer
    // que l'erreur n'apprendrait rien. Le rond PLEIN, lui, ne va qu'au choix
    // fait — c'est lui qui dit « c'est toi qui as répondu ça ».
    final tone = correct && answered
        ? AppColors.success
        : picked
        ? AppColors.danger
        : null;

    return Semantics(
      button: onTap != null,
      selected: picked || pending,
      label: '$letter. $label',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          type: boxed ? MaterialType.canvas : MaterialType.transparency,
          color: boxed ? AppColors.darkSurfaceAlt : null,
          shape: boxed
              ? RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                  side: BorderSide(
                    color: pending
                        ? AppColors.primaryLightBorder
                        : AppColors.darkBorder,
                  ),
                )
              : null,
          clipBehavior: boxed ? Clip.antiAlias : Clip.none,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: boxed ? AppSpacing.md : 0,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.tap,
                      curve: AppMotion.standard,
                      width: _radioSize,
                      height: _radioSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: picked ? tone : null,
                        border: picked
                            ? null
                            : Border.all(
                                color:
                                    tone ??
                                    (pending
                                        ? AppColors.primaryLight
                                        : AppColors.quizLetterBorder),
                                width: tone == null && !pending
                                    ? 1.5
                                    : _ringWidth,
                              ),
                      ),
                      child: picked
                          ? Icon(
                              correct ? AppIcons.check : AppIcons.close,
                              size: 14,
                              color: AppColors.darkBackground,
                            )
                          : pending
                          ? Center(
                              child: Container(
                                width: _pendingDot,
                                height: _pendingDot,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.body.copyWith(
                          fontWeight: picked
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: answered && !picked && !correct
                              ? AppColors.darkTextTertiary
                              : AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
