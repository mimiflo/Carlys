import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';

/// Carte « séance du jour » (dégradé violet) avec l'UNIQUE CTA accent de
/// l'écran : démarrer — ou reprendre — la séance.
///
/// Le domaine n'a pas de programme planifié : le titre reprend la séance en
/// cours quand il y en a une, sinon l'entraînement libre. Les pastilles ne
/// portent que des faits mesurés (durée écoulée, exercices, séries).
class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard({
    required this.activeWorkout,
    required this.onStart,
    super.key,
  });

  final WorkoutWithSets? activeWorkout;
  final Future<void> Function() onStart;

  /// Maquette : padding interne de 20 (md + xxs) et gouttière verticale 16.
  static const double _padding = AppSpacing.md + AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    final active = activeWorkout;
    final name = active?.session.name?.trim();
    final title = active == null
        ? 'Entraînement libre'
        : (name == null || name.isEmpty ? 'Séance en cours' : name);
    final elapsed =
        active == null ? null : _elapsed(active.session.startedAt);
    final facts = _facts(active);

    return Container(
      padding: const EdgeInsets.all(_padding),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionLabel('Séance du jour'),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      title,
                      style: AppTypography.title
                          .copyWith(color: AppColors.darkTextPrimary),
                    ),
                  ],
                ),
              ),
              if (elapsed != null) ...[
                const SizedBox(width: AppSpacing.sm),
                AppPill(
                  label: formatDurationShort(elapsed.inSeconds),
                  tone: AppPillTone.accent,
                  mono: true,
                ),
              ],
            ],
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final fact in facts) AppPill(label: fact),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _AccentCta(
            label: active == null ? 'Démarrer la séance' : 'Reprendre la séance',
            onPressed: onStart,
          ),
        ],
      ),
    );
  }

  /// Temps écoulé depuis le début de la séance ; `null` si l'horloge locale
  /// place le départ dans le futur — on n'affiche alors pas de durée.
  static Duration? _elapsed(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt.toLocal());
    return elapsed.isNegative ? null : elapsed;
  }

  /// Faits mesurés de la séance en cours — rien à afficher sans séance.
  static List<String> _facts(WorkoutWithSets? active) {
    if (active == null) {
      return const [];
    }
    final exercises =
        active.sets.map((entry) => entry.exerciseName).toSet().length;
    final sets = active.setsCount;
    return [
      if (exercises > 0) '$exercises exercice${exercises > 1 ? 's' : ''}',
      if (sets > 0) '$sets série${sets > 1 ? 's' : ''}',
    ];
  }
}

/// CTA accent : texte sombre sur lime, pleine largeur, halo lime diffus.
class _AccentCta extends StatelessWidget {
  const _AccentCta({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  /// Géométrie de la maquette : icône 19, halo `0 12px 30px -12px` — le
  /// rayon négatif resserre la lueur sous le bouton.
  static const double _iconSize = 19;
  static const double _glowBlur = 30;
  static const double _glowSpread = -12;
  static const double _glowOffset = 12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.buttonAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.7),
              blurRadius: _glowBlur,
              spreadRadius: _glowSpread,
              offset: const Offset(0, _glowOffset),
            ),
          ],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.darkBackground,
            textStyle: AppTypography.subheading
                .copyWith(fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.play, size: _iconSize),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
