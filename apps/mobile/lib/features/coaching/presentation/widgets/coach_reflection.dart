import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'coach_reflection_parts.dart';

/// La RÉFLEXION du coach : ce qu'il fait vraiment avant de répondre —
/// « Je regarde tes records », « Je cherche des exercices », « Je prépare
/// ta séance » — et combien de temps.
///
/// En direct ([live]), dépliée : les étapes apparaissent UNE À UNE, chacune
/// au moins [AppMotion.reflectionStep] avec ses trois points animés avant sa
/// coche ([done]) — le flux peut annoncer et finir une lecture d'avance dans
/// la même image, l'écran la laisse lire ; ses étapes faites, il réfléchit
/// encore (« Je réfléchis à ta réponse »), et le chrono court
/// (« Réflexion · 12 s ») jusqu'au premier mot (« Réflexion en 14 s »).
/// Sans étape encore, il réfléchit déjà : le chrono court dès le début,
/// jamais un « Réfléchit… » nu qui deviendrait d'un coup « Réflexion en
/// 16 s ». Archivée, repliée en une ligne (« Réflexion en 30 s · 3 étapes »)
/// qu'on déplie d'un appui ; sans étape, sa durée seule ; ni l'une ni
/// l'autre (copie ancienne), rien.
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

  /// En direct : combien d'étapes sont apparues, et lesquelles ont eu leur
  /// temps à l'écran. Des minuteries seulement, aucune horloge : une étape
  /// mûrit [AppMotion.reflectionStep] après son apparition.
  int _shown = 0;
  final Set<int> _ripe = {};
  final List<Timer> _timers = [];

  static const double _iconSize = CoachReflectionStep.iconSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pace();
  }

  @override
  void didUpdateWidget(CoachReflection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pace();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  /// Fait apparaître l'étape suivante quand la précédente a mûri. Une seule
  /// à la fois : sa minuterie rappelle `_pace` pour la suivante.
  void _pace() {
    if (!widget.live) return;
    if (widget.steps.length < _shown) {
      for (final timer in _timers) {
        timer.cancel();
      }
      _timers.clear();
      _shown = 0;
      _ripe.clear();
    }
    if (_shown == widget.steps.length) return;
    if (_shown > 0 && !_ripe.contains(_shown - 1)) return;
    final index = _shown++;
    _timers.add(
      Timer(AppMotion.resolve(context, AppMotion.reflectionStep), () {
        if (!mounted) return;
        setState(() {
          _ripe.add(index);
          _pace();
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.live
        ? widget.steps.take(_shown).toList()
        : widget.steps;
    // Cochée à l'écran : finie, ET montrée en cours le temps d'une étape.
    bool current(int index) =>
        widget.live &&
        !(_ripe.contains(index) && widget.done.contains(steps[index]));
    final foldable = !widget.live && steps.isNotEmpty;
    if (!widget.live && !foldable && widget.seconds == null) {
      return const SizedBox.shrink();
    }
    final open = widget.live || _open;
    final thinking =
        widget.live &&
        !widget.writing &&
        steps.length == widget.steps.length &&
        !List.generate(steps.length, current).contains(true);
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
        if (foldable) ...[
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
        if (!foldable)
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
          child: open && (steps.isNotEmpty || thinking)
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, label) in steps.indexed)
                        CoachReflectionStep(
                          label: label,
                          // Même après le premier mot : il écrit, puis
                          // cherche des exercices.
                          current: current(index),
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
    final stepCount = switch (count) {
      0 => '',
      1 => ' · 1 étape',
      _ => ' · $count étapes',
    };
    if (!widget.live) {
      final seconds = widget.seconds;
      return Text(
        seconds == null
            ? 'Réflexion$stepCount'
            : 'Réflexion en ${reflectionDuration(seconds)}$stepCount',
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
