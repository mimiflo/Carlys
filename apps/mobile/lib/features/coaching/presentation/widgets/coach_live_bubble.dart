import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'coach_message_bubble.dart';
import 'coach_reflection.dart';

/// La réponse du coach PENDANT qu'elle s'écrit.
///
/// Trois temps, comme une personne sollicitée : « en attente » quand d'autres
/// passent avant (le coach répond à un nombre fixe de personnes à la fois),
/// puis sa réflexion — ce qu'il fait vraiment, étape par étape (« Je regarde
/// tes records »), ou « Réfléchit… » s'il n'a rien à lire —, puis le texte
/// qui s'allonge mot après mot. La réplique archivée la remplace à la fin.
class CoachLiveBubble extends StatelessWidget {
  const CoachLiveBubble({
    required this.text,
    this.ahead,
    this.steps = const [],
    this.done = const {},
    this.since,
    this.thoughtFor,
    this.maxWidth = double.infinity,
    super.key,
  });

  /// La réponse reçue jusqu'ici ; vide tant que le coach réfléchit.
  final String text;

  /// Sa réflexion jusqu'ici ([CoachReflection]) : ses étapes, celles qui
  /// sont finies, son début et, le premier mot écrit, sa durée.
  final List<String> steps;
  final Set<String> done;
  final DateTime? since;
  final Duration? thoughtFor;

  /// Demandes qui passent avant, en file d'attente ; `null` : son tour.
  final int? ahead;
  final double maxWidth;

  String get _waiting {
    final ahead = this.ahead;
    if (ahead == null) return 'Réfléchit…';
    if (ahead == 0) return 'En attente · tu es le prochain';
    return 'En attente · $ahead avant toi';
  }

  @override
  Widget build(BuildContext context) {
    final status = Semantics(
      label: ahead == null
          ? 'Le coach réfléchit'
          : 'Le coach est sollicité : $_waiting',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoachThinkingDots(),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _waiting,
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
    final reflection = CoachReflection(
      steps: steps,
      done: done,
      live: true,
      writing: text.isNotEmpty,
      since: since,
      thoughtFor: thoughtFor,
    );
    return CoachBubble(
      isUser: false,
      maxWidth: maxWidth,
      // Le texte commencé, la réflexion continue dessous jusqu'à la fin du
      // tour : entre deux recherches, rien ne s'écrit, et la bulle ne doit
      // pas sembler finie.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (steps.isNotEmpty) reflection,
          if (text.isEmpty && steps.isEmpty) status,
          if (text.isNotEmpty) ...[
            if (steps.isNotEmpty) const SizedBox(height: AppSpacing.sm),
            CoachBubbleText(text, isUser: false),
            const SizedBox(height: AppSpacing.sm),
            status,
          ],
        ],
      ),
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
