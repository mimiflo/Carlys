import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'coach_reflection_parts.dart';

/// La RÉFLEXION du coach : ce qu'il fait vraiment avant de répondre —
/// « Je regarde tes records », « Je cherche des exercices », « Je prépare
/// ta séance » — et combien de temps.
///
/// En direct ([live]), dépliée : chaque étape a ses trois points animés tant
/// qu'elle se fait, puis sa coche ([done]) ; ses étapes faites, il réfléchit
/// encore (« Je réfléchis à ta réponse »), et le chrono court
/// (« Réflexion · 12 s ») jusqu'au premier mot (« Réflexion en 14 s »).
/// Archivée, repliée en une ligne (« Réflexion en 30 s · 3 étapes ») qu'on
/// déplie d'un appui. Sans étape, rien.
class CoachReflection extends StatefulWidget {
  const CoachReflection({
    required this.steps,
    this.done = const {},
    this.live = false,
    this.writing = false,
    this.since,
    this.thoughtFor,
    this.seconds,
    super.key,
  });

  final List<String> steps;

  /// En direct : les étapes finies ; archivée, toutes le sont.
  final Set<String> done;

  /// Le tour s'écrit encore : dépliée, sans rien à replier.
  final bool live;

  /// Le premier mot est écrit : la réflexion est finie.
  final bool writing;

  /// En direct : le début de la réflexion, d'où court le chrono.
  final DateTime? since;

  /// En direct : sa durée, figée au premier mot.
  final Duration? thoughtFor;

  /// Archivée : sa durée, en secondes, telle que le serveur l'a mesurée.
  final int? seconds;

  @override
  State<CoachReflection> createState() => _CoachReflectionState();
}

class _CoachReflectionState extends State<CoachReflection> {
  bool _open = false;

  static const double _iconSize = CoachReflectionStep.iconSize;

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final open = widget.live || _open;
    final thinking =
        widget.live && !widget.writing && steps.every(widget.done.contains);
    final header = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          AppIcons.coachReflection,
          size: _iconSize,
          color: AppColors.primaryLight,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: _title()),
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
                      for (final label in steps)
                        CoachReflectionStep(
                          label: label,
                          // Même après le premier mot : il écrit, puis
                          // cherche des exercices.
                          current: widget.live && !widget.done.contains(label),
                        ),
                      // Ses lectures faites, il réfléchit encore : la bulle
                      // ne doit pas sembler arrêtée.
                      if (thinking)
                        const CoachReflectionStep(
                          label: 'Je réfléchis à ta réponse',
                          current: true,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _title() {
    final style = AppTypography.label.copyWith(color: AppColors.primaryLight);
    final count = widget.steps.length;
    final stepCount = count == 1 ? '1 étape' : '$count étapes';
    if (!widget.live) {
      final seconds = widget.seconds;
      return Text(
        seconds == null
            ? 'Réflexion · $stepCount'
            : 'Réflexion en ${reflectionDuration(seconds)} · $stepCount',
        style: style,
      );
    }
    final thoughtFor = widget.thoughtFor;
    if (widget.writing && thoughtFor != null) {
      return Text(
        // Arrondie comme le serveur arrondit la durée archivée.
        'Réflexion en ${reflectionDuration((thoughtFor.inMilliseconds / 1000).round())}',
        style: style,
      );
    }
    final since = widget.since;
    if (widget.writing || since == null) return Text('Réflexion', style: style);
    return CoachReflectionTimer(since: since, style: style);
  }
}
