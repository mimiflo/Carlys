import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// En-tête de la séance active : la croix, « Séance en cours » et son
/// chrono, la pastille de la séance suivie, le changement d'exercice.
class ActiveWorkoutHeader extends StatelessWidget {
  const ActiveWorkoutHeader({
    required this.startedAt,
    required this.sessionName,
    required this.onClose,
    required this.onPickExercise,
    this.templateName,
    super.key,
  });

  final DateTime startedAt;

  /// Nom de la séance, `null` quand elle a été démarrée sans intitulé.
  final String? sessionName;

  /// Nom du modèle lancé — provenance immuable de la séance, `null` pour une
  /// séance libre. Il prime sur [sessionName] dans la pastille : on sait à
  /// tout moment quel programme on est en train de suivre.
  final String? templateName;

  final VoidCallback onClose;
  final VoidCallback onPickExercise;

  @override
  Widget build(BuildContext context) {
    final named = sessionName?.trim();
    final pill =
        templateName ?? (named == null || named.isEmpty ? null : named);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppRoundIconButton(
            icon: AppIcons.close,
            tooltip: 'Fermer la séance',
            color: AppColors.darkTextSecondary,
            onPressed: onClose,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Séance en cours',
                    textAlign: TextAlign.center,
                    style: AppTypography.title.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ExcludeSemantics(
                      child: Icon(
                        AppIcons.timer,
                        size: 24,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // « 1:05:42 » en texte agrandi tient en se resserrant.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _ElapsedTimer(startedAt: startedAt),
                      ),
                    ),
                  ],
                ),
                ExcludeSemantics(
                  child: Text(
                    'TEMPS ÉCOULÉ',
                    style: AppTypography.labelMono.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ),
                if (pill != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AppPill(label: pill, tone: AppPillTone.primary),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppRoundIconButton(
            icon: AppIcons.add,
            tooltip: 'Changer d’exercice',
            onPressed: onPickExercise,
          ),
        ],
      ),
    );
  }
}

/// Chrono de séance, recalculé chaque seconde depuis l'horodatage de début.
///
/// Le battement vit dans l'état, pas dans `build` : un `Stream.periodic`
/// construit à chaque rendu était remplacé — donc résilié puis recréé — à
/// chaque reconstruction, or l'écran se reconstruit à chaque série validée.
/// L'affichage restait juste (l'heure courante sert de repli), mais la phase
/// du battement repartait de zéro et la seconde affichée pouvait tenir près
/// de deux secondes avant de sauter. Ici, un seul minuteur, annulé à la
/// destruction : il ne survit pas à l'écran.
class _ElapsedTimer extends StatefulWidget {
  const _ElapsedTimer({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _now.difference(widget.startedAt.toLocal());
    return Text(
      formatChrono(elapsed.inSeconds),
      style: AppTypography.resized(
        AppTypography.metricL,
        32,
      ).copyWith(color: AppColors.darkTextPrimary),
      semanticsLabel: 'Durée écoulée',
    );
  }
}
