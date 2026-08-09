import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';

/// Une réplique de la conversation.
///
/// Le coach parle à gauche sur une surface sombre, l'utilisateur à droite en
/// violet de marque. Le coin le plus proche du bord est **rabattu** : c'est ce
/// détail qui donne à une bulle sa direction, plus que son alignement.
class CoachMessageBubble extends StatelessWidget {
  const CoachMessageBubble({
    required this.message,
    required this.maxWidth,
    super.key,
  });

  final CoachMessage message;

  /// Largeur maximale de la bulle. Calculée par l'écran plutôt que déduite de
  /// `MediaQuery` : une bulle doit se plier à la colonne qui la contient, pas
  /// à l'écran — sinon elle déborde dès qu'on la place ailleurs.
  final double maxWidth;

  /// Rayon du coin rabattu, côté locuteur.
  static const double _spokenCorner = AppRadius.sm;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == CoachRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : AppColors.darkSurface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(
                isUser ? AppRadius.lg : _spokenCorner,
              ),
              bottomRight: Radius.circular(
                isUser ? _spokenCorner : AppRadius.lg,
              ),
            ),
            // Sur fond très sombre, une bulle sans liseré se dissout dans la
            // page ; le violet, lui, se tient seul.
            border: isUser
                ? null
                : const Border.fromBorderSide(
                    BorderSide(color: AppColors.darkBorder),
                  ),
          ),
          child: Text(
            message.content,
            style: AppTypography.body.copyWith(
              color: isUser ? AppColors.neutral0 : AppColors.darkTextPrimary,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

/// Point de suspension pendant que le coach compose sa réponse.
///
/// Sans streaming, c'est le SEUL signe de vie entre la question et la
/// réponse : il n'est pas décoratif, il empêche l'écran de paraître figé.
class CoachTypingBubble extends StatelessWidget {
  const CoachTypingBubble({super.key});

  static const double _dotSize = 6;
  static const int _dotCount = 3;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.sm),
            bottomRight: Radius.circular(AppRadius.lg),
          ),
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.darkBorder),
          ),
        ),
        child: Semantics(
          label: 'Le coach rédige sa réponse',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _dotCount; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xxs),
                Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    // Les points s'éteignent vers la droite : la lecture suit
                    // le sens de l'écriture.
                    color: AppColors.darkTextSecondary.withValues(
                      alpha: 1 - i * 0.28,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
