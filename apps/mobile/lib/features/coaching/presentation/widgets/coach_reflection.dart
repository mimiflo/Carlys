import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'coach_live_bubble.dart';

/// La RÉFLEXION du coach : ce qu'il a vraiment fait avant de répondre —
/// « Je regarde tes records », « Je cherche des exercices », « Je prépare
/// ta séance ».
///
/// En direct ([live]), dépliée : chaque étape s'ajoute, et la dernière
/// s'anime tant qu'elle est en cours ([inProgress]). Archivée, repliée en
/// une ligne (« Réflexion · 3 étapes ») qu'on déplie d'un appui. Sans étape,
/// rien.
class CoachReflection extends StatefulWidget {
  const CoachReflection({
    required this.steps,
    this.live = false,
    this.inProgress = false,
    super.key,
  });

  final List<String> steps;

  /// Le tour s'écrit encore : dépliée, sans rien à replier.
  final bool live;

  /// La dernière étape se fait encore : rien n'est écrit depuis.
  final bool inProgress;

  @override
  State<CoachReflection> createState() => _CoachReflectionState();
}

class _CoachReflectionState extends State<CoachReflection> {
  bool _open = false;

  static const double _iconSize = AppSpacing.md;

  String get _summary {
    final count = widget.steps.length;
    return count == 1 ? 'Réflexion · 1 étape' : 'Réflexion · $count étapes';
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final open = widget.live || _open;
    final header = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          AppIcons.coachReflection,
          size: _iconSize,
          color: AppColors.primaryLight,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            widget.live ? 'Réflexion' : _summary,
            style: AppTypography.label.copyWith(color: AppColors.primaryLight),
          ),
        ),
        if (!widget.live) ...[
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            open ? AppIcons.collapse : AppIcons.expand,
            size: _iconSize,
            color: AppColors.darkTextSecondary,
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.live)
          header
        else
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: header,
              ),
            ),
          ),
        AnimatedSize(
          duration: AppMotion.resolve(context, AppMotion.normal),
          alignment: Alignment.topLeft,
          child: open
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        _Step(
                          label: steps[i],
                          current: widget.inProgress && i == steps.length - 1,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Une étape : faite (coche), ou en cours (les points qui pulsent).
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.current});

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
                  ? const CoachThinkingDots()
                  : const Icon(
                      AppIcons.coachStepDone,
                      size: _CoachReflectionState._iconSize,
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
