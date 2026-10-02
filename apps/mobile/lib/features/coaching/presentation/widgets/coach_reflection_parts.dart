import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import 'coach_live_bubble.dart';

/// Les pièces de [CoachReflection] : une étape, le chrono, la durée lisible.

/// « 12 s », « 1:05 min » : la durée lisible de l'appli.
String reflectionDuration(int seconds) {
  final duration = formatDuration(seconds);
  return '${duration.value} ${duration.unit}';
}

/// Le chrono de la réflexion, à la seconde.
class CoachReflectionTimer extends StatefulWidget {
  const CoachReflectionTimer({
    required this.since,
    required this.style,
    super.key,
  });

  final DateTime since;
  final TextStyle style;

  @override
  State<CoachReflectionTimer> createState() => _CoachReflectionTimerState();
}

class _CoachReflectionTimerState extends State<CoachReflectionTimer> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since).inSeconds;
    return Text(
      'Réflexion · ${reflectionDuration(elapsed < 0 ? 0 : elapsed)}',
      style: widget.style,
    );
  }
}

/// Une étape : en cours (les points qui pulsent), puis faite (la coche).
class CoachReflectionStep extends StatelessWidget {
  const CoachReflectionStep({
    required this.label,
    required this.current,
    super.key,
  });

  /// La taille des icônes de la réflexion : coche et titre s'alignent.
  static const double iconSize = AppSpacing.md;

  /// Les points d'une étape en cours.
  static const double dotSize = 4;

  final String label;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Semantics(
        label: current ? '$label, en cours' : '$label, fait',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              // Les trois points de « réfléchit » y tiennent ; la coche,
              // calée à gauche, s'aligne sur l'icône du titre.
              width: AppSpacing.lg + AppSpacing.xxs,
              alignment: Alignment.centerLeft,
              child: current
                  // Plus petits que ceux de « Réfléchit… » : à la taille du
                  // texte d'une étape.
                  ? const CoachThinkingDots(dotSize: dotSize)
                  : const Icon(
                      AppIcons.coachStepDone,
                      size: CoachReflectionStep.iconSize,
                      color: AppColors.primaryLight,
                    ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                label,
                style: AppTypography.label.copyWith(
                  color: current
                      ? AppColors.darkTextPrimary
                      : AppColors.darkTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
