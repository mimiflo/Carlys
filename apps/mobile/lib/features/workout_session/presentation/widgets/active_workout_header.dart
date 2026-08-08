import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// En-tête de la séance active (maquette 2e) : croix de fermeture, chrono
/// mono centré surmontant le nom de la séance, action d'exercice à droite.
class ActiveWorkoutHeader extends StatelessWidget {
  const ActiveWorkoutHeader({
    required this.startedAt,
    required this.sessionName,
    required this.onClose,
    required this.onPickExercise,
    super.key,
  });

  final DateTime startedAt;

  /// Nom de la séance, `null` quand elle a été démarrée sans intitulé.
  final String? sessionName;
  final VoidCallback onClose;
  final VoidCallback onPickExercise;

  /// Icônes d'en-tête de la maquette (23 px, boîte tactile 44).
  static const double _iconSize = 23;
  static const double _tapSize = 44;

  @override
  Widget build(BuildContext context) {
    final name = sessionName == null || sessionName!.trim().isEmpty
        ? 'Séance en cours'
        : sessionName!;

    return Padding(
      // La gouttière (22) moins la demi-boîte tactile : les icônes tombent
      // exactement sur la marge de la maquette.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: AppIcons.close,
            tooltip: 'Fermer la séance',
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              children: [
                _ElapsedTimer(startedAt: startedAt),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMono.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.08,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: AppIcons.add,
            tooltip: 'Changer d’exercice',
            onPressed: onPickExercise,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: ActiveWorkoutHeader._tapSize,
        height: ActiveWorkoutHeader._tapSize,
      ),
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: ActiveWorkoutHeader._iconSize,
        color: AppColors.darkTextSecondary,
      ),
    );
  }
}

/// Chrono de séance, recalculé chaque seconde depuis l'horodatage de début.
class _ElapsedTimer extends StatelessWidget {
  const _ElapsedTimer({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      builder: (context, snapshot) {
        final elapsed =
            (snapshot.data ?? DateTime.now()).difference(startedAt.toLocal());
        return Text(
          formatChrono(elapsed.inSeconds),
          style: AppTypography.metricM.copyWith(
            fontSize: 17,
            letterSpacing: -0.34,
            color: AppColors.darkTextPrimary,
          ),
          semanticsLabel: 'Durée écoulée',
        );
      },
    );
  }
}
