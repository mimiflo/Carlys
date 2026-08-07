import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';

/// Carte « séance du jour » (gradient primary) avec l'UNIQUE CTA accent de
/// l'écran : démarrer — ou reprendre — la séance.
class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard({
    required this.activeWorkout,
    required this.onStart,
    super.key,
  });

  final WorkoutWithSets? activeWorkout;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final resuming = activeWorkout != null;
    final setsCount = activeWorkout?.setsCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        borderRadius: AppRadius.cardMainAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryCardStrong, AppColors.primaryCardSoft],
        ),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.primaryLightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: AppSectionLabel('Séance du jour')),
              if (resuming)
                AppPill(
                  label: '$setsCount SÉRIE${setsCount > 1 ? 'S' : ''}',
                  tone: AppPillTone.accent,
                  mono: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            resuming ? 'Séance en cours' : 'Entraînement libre',
            style:
                AppTypography.title.copyWith(color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppPill(label: 'À ton rythme'),
              AppPill(label: 'Catalogue complet'),
            ],
          ),
          const SizedBox(height: 18),
          _AccentCta(
            label: resuming ? 'Reprendre la séance' : 'Démarrer la séance',
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

/// CTA accent : texte sombre sur lime, ombre lime floue 30.
class _AccentCta extends StatelessWidget {
  const _AccentCta({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.buttonAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.darkBackground,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
