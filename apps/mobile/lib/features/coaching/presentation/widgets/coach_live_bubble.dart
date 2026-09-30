import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'coach_message_bubble.dart';

/// La réponse du coach PENDANT qu'elle s'écrit.
///
/// Deux temps, comme une personne qui répond : d'abord « réfléchit… »
/// (le coach lit tes séances et tes records avant d'écrire), puis le texte
/// qui s'allonge mot après mot. La réplique archivée la remplace à la fin.
class CoachLiveBubble extends StatelessWidget {
  const CoachLiveBubble({
    required this.text,
    this.maxWidth = double.infinity,
    super.key,
  });

  /// La réponse reçue jusqu'ici ; vide tant que le coach réfléchit.
  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return CoachBubble(
        isUser: false,
        maxWidth: maxWidth,
        child: Semantics(
          label: 'Le coach réfléchit',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoachThinkingDots(),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Réfléchit…',
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return CoachBubble(
      isUser: false,
      maxWidth: maxWidth,
      child: CoachBubbleText(text, isUser: false),
    );
  }
}

/// Trois points qui s'allument l'un après l'autre : le seul signe de vie
/// avant le premier mot. Immobiles quand le système réduit les animations.
class CoachThinkingDots extends StatefulWidget {
  const CoachThinkingDots({super.key});

  /// Un tour complet de la vague : le rythme des anneaux de l'appli.
  static const Duration cycle = AppMotion.ring;
  static const double _dotSize = 6;
  static const int _dotCount = 3;

  @override
  State<CoachThinkingDots> createState() => _CoachThinkingDotsState();
}

class _CoachThinkingDotsState extends State<CoachThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CoachThinkingDots.cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.resolve(context, CoachThinkingDots.cycle) == Duration.zero) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < CoachThinkingDots._dotCount; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xxs),
            Container(
              width: CoachThinkingDots._dotSize,
              height: CoachThinkingDots._dotSize,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: _alpha(i)),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Chaque point culmine à son tour ; à l'arrêt, ils s'éteignent vers la
  /// droite, comme avant.
  double _alpha(int i) {
    if (!_controller.isAnimating) return 1 - i * 0.28;
    final phase = (_controller.value - i / CoachThinkingDots._dotCount) % 1;
    return 0.35 + 0.65 * math.max(0, math.sin(phase * math.pi));
  }
}
