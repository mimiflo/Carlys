import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import 'section_title_bar.dart';

/// LA SÉANCE DU JOUR : la seule action forte de l'accueil.
///
/// Elle ne se distingue plus par un fond violet — c'était une carte parmi
/// d'autres cartes colorées — mais par son DISQUE ORANGE, unique aplat
/// d'accent de l'écran. Un rond de 58 se vise au pouce sans regarder, ce
/// qu'un bouton pleine largeur en bas de carte ne permettait pas.
///
/// Sous un filet, la seconde porte : partir d'un modèle enregistré plutôt
/// que d'une séance à blanc. Elle disparaît pendant une séance — on n'en
/// lance pas une autre quand une est ouverte.
class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard({
    required this.activeWorkout,
    required this.onStart,
    required this.onOpenTemplates,
    this.templateCount,
    super.key,
  });

  final WorkoutWithSets? activeWorkout;
  final Future<void> Function() onStart;
  final VoidCallback onOpenTemplates;

  /// Nombre de modèles enregistrés. `null` tant qu'ils ne sont pas lus.
  final int? templateCount;

  @override
  Widget build(BuildContext context) {
    final active = activeWorkout;
    final name = active?.session.name?.trim();
    final title = active == null
        ? 'Entraînement libre'
        : (name == null || name.isEmpty ? 'Séance en cours' : name);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.cardSecondary),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.padCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Heading(title: title, active: active)),
                const SizedBox(width: AppSpacing.md),
                _PlayDisc(started: active != null, onPressed: onStart),
              ],
            ),
            if (active == null) ...[
              const SizedBox(height: AppSpacing.md - 1),
              const Divider(height: 1, color: AppColors.darkBorder),
              const SizedBox(height: AppSpacing.gapRow),
              _TemplateRow(count: templateCount, onTap: onOpenTemplates),
            ],
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.active});

  final String title;
  final WorkoutWithSets? active;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              AppIcons.spark,
              size: SectionTitleBar.iconSize,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.xs - 1),
            Text(
              'SÉANCE DU JOUR',
              style: AppTypography.labelMono
                  .copyWith(color: AppColors.darkTextTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gapTile - 1),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.title.copyWith(
            fontSize: 20,
            letterSpacing: -0.6,
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs - 1),
        Text(
          _support(active),
          style:
              AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
        ),
      ],
    );
  }

  /// Ce que la carte peut dire sans rien inventer : les faits mesurés de la
  /// séance en cours, ou la promesse d'une séance libre.
  ///
  /// La durée écoulée tient dans cette phrase plutôt que dans une pastille :
  /// c'est un fait de plus, pas une deuxième chose à regarder.
  static String _support(WorkoutWithSets? active) {
    if (active == null) {
      return 'Tu choisis les exercices en cours de route.';
    }

    final elapsed = _elapsed(active.session.startedAt);
    final since = elapsed == null
        ? 'En cours'
        : 'En cours depuis ${formatDurationShort(elapsed.inSeconds).toLowerCase()}';

    final exercises =
        active.sets.map((entry) => entry.exerciseName).toSet().length;
    final sets = active.setsCount;
    if (exercises == 0) {
      return '$since. Reprends où tu en étais.';
    }
    return '$since — $exercises exercice${exercises > 1 ? 's' : ''}, '
        '$sets série${sets > 1 ? 's' : ''}.';
  }

  /// Temps écoulé depuis le début de la séance ; `null` si l'horloge locale
  /// place le départ dans le futur — on n'affiche alors pas de durée.
  static Duration? _elapsed(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt.toLocal());
    return elapsed.isNegative ? null : elapsed;
  }
}

/// Le disque de lecture. Halo resserré sous le bouton : le rayon négatif
/// garde la lueur au pied du disque au lieu de l'étaler sur la carte.
class _PlayDisc extends StatelessWidget {
  const _PlayDisc({required this.started, required this.onPressed});

  final bool started;
  final Future<void> Function() onPressed;

  static const double _size = 58;
  static const double _iconSize = 28;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // Nœud À PART ENTIÈRE : sans cela, l'annotation se fond dans le bloc
      // de texte de la carte et le lecteur d'écran ne propose plus de bouton
      // à activer, seulement un paragraphe qui se termine par « démarrer ».
      container: true,
      label: started ? 'Reprendre la séance' : 'Démarrer la séance',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.8),
                blurRadius: 26,
                spreadRadius: -10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: const SizedBox.square(
                dimension: _size,
                child: Icon(
                  AppIcons.play,
                  size: _iconSize,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La seconde porte : un modèle enregistré plutôt qu'une séance à blanc.
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.count, required this.onTap});

  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final saved = count;
    return Semantics(
      button: true,
      container: true,
      label: 'Lancer un modèle de séance enregistré',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              const Icon(
                AppIcons.programs,
                size: 18,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Lancer un modèle',
                  style: AppTypography.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              if (saved != null && saved > 0) ...[
                Text(
                  '$saved ENREGISTRÉ${saved > 1 ? 'S' : ''}',
                  style: AppTypography.labelMono
                      .copyWith(color: AppColors.darkTextTertiary),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              const Icon(
                AppIcons.chevronRight,
                size: 18,
                color: AppColors.darkTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
