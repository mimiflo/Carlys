import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import 'coach_reflection.dart';

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

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == CoachRole.user;
    final text = CoachBubbleText(message.content, isUser: isUser);
    return CoachBubble(
      isUser: isUser,
      maxWidth: maxWidth,
      // Sa réflexion, repliée au-dessus de la réponse : ce qu'il a lu.
      child: message.steps.isEmpty && message.thinkingSeconds == null
          ? text
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoachReflection(
                  steps: message.steps,
                  seconds: message.thinkingSeconds,
                ),
                const SizedBox(height: AppSpacing.xs),
                text,
              ],
            ),
    );
  }
}

/// Le cadre d'une bulle, partagé par les répliques archivées et par celle qui
/// s'écrit en direct : une seule forme, qu'on ne recopie pas.
class CoachBubble extends StatelessWidget {
  const CoachBubble({
    required this.isUser,
    required this.child,
    this.maxWidth = double.infinity,
    super.key,
  });

  final bool isUser;
  final double maxWidth;
  final Widget child;

  /// Rayon du coin rabattu, côté locuteur.
  static const double _spokenCorner = AppRadius.sm;

  @override
  Widget build(BuildContext context) {
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
          child: child,
        ),
      ),
    );
  }
}

/// Le texte d'une bulle, dans la couleur de celui qui parle.
class CoachBubbleText extends StatelessWidget {
  const CoachBubbleText(this.text, {required this.isUser, super.key});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.body.copyWith(
        color: isUser ? AppColors.neutral0 : AppColors.darkTextPrimary,
        height: 1.45,
      ),
    );
  }
}
