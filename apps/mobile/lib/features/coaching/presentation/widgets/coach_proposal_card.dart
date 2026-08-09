import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';

/// Séance proposée par le coach, avec sa seule sortie : la lancer.
///
/// C'est la pièce qui sépare un coach d'un robot de conversation — l'échange
/// ne se termine pas par un conseil mais par une **action exécutable**. Rien
/// n'est écrit tant que l'utilisateur n'a pas appuyé : la carte est un
/// document, pas une séance.
class CoachProposalCard extends StatelessWidget {
  const CoachProposalCard({
    required this.proposal,
    required this.onOpen,
    required this.maxWidth,
    super.key,
  });

  final CoachSessionProposal proposal;
  final VoidCallback onOpen;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.darkSurfaceAlt,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.darkBorderStrong),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ProposalHeader(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                proposal.name,
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _summary,
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final (index, exercise) in proposal.exercises.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpacing.xs),
                _ExerciseRow(exercise: exercise),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Voir la séance',
                onPressed: onOpen,
                isExpanded: true,
                icon: AppIcons.play,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// « 4 exercices · 25 min » — ce que l'utilisateur veut savoir avant même de
  /// lire le détail.
  String get _summary {
    final count = proposal.exercises.length;
    final exercises = count > 1 ? '$count exercices' : '$count exercice';
    return '$exercises · ${proposal.estimatedMinutes} min';
  }
}

class _ProposalHeader extends StatelessWidget {
  const _ProposalHeader();

  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          AppIcons.coach,
          size: _iconSize,
          color: AppColors.primaryLight,
        ),
        const SizedBox(width: AppSpacing.xxs + 2),
        Text(
          'SÉANCE ADAPTÉE',
          style: AppTypography.labelMono.copyWith(
            color: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final CoachProposedExercise exercise;

  /// Largeur de la pastille du nombre de séries. Fixe, pour que les libellés
  /// s'alignent d'une ligne à l'autre.
  static const double _countWidth = 34;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _countWidth,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs / 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              '${exercise.setCount}×',
              style: AppTypography.labelMono.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            exercise.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          exercise.detail,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}
