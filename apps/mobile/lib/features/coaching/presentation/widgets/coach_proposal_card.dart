import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import 'coach_card_frame.dart';

/// Séance proposée par le coach, avec sa seule sortie : la lancer.
///
/// C'est la pièce qui sépare un coach d'un robot de conversation — l'échange
/// ne se termine pas par un conseil mais par une **action exécutable**. La
/// carte est un document, pas une séance lancée : rien ne démarre tant que
/// l'utilisateur n'a pas appuyé. Elle est en revanche GARDÉE d'office comme
/// modèle (« Mes modèles », catégorie Coach — [saved]), pour ne pas se
/// perdre avec le fil ; [onOpenSaved] y mène.
class CoachProposalCard extends StatelessWidget {
  const CoachProposalCard({
    required this.proposal,
    required this.onOpen,
    required this.maxWidth,
    this.saved = false,
    this.onOpenSaved,
    super.key,
  });

  final CoachSessionProposal proposal;
  final VoidCallback onOpen;
  final double maxWidth;

  /// Sa copie existe dans les modèles, sur la preuve du serveur.
  final bool saved;

  /// Ouvre cette copie dans l'éditeur de modèles.
  final VoidCallback? onOpenSaved;

  @override
  Widget build(BuildContext context) {
    return CoachCardFrame(
      maxWidth: maxWidth,
      children: [
        const CoachCardHeader(icon: AppIcons.coach, label: 'SÉANCE ADAPTÉE'),
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
        // Une proposition acceptée a déjà SA séance : le dire, et
        // proposer d'y retourner plutôt qu'un lancement qui ressemble
        // à un premier.
        if (proposal.isAccepted) ...[
          Text(
            'Séance déjà lancée',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        AppButton(
          label: proposal.isAccepted ? 'Reprendre la séance' : 'Voir la séance',
          onPressed: onOpen,
          isExpanded: true,
          icon: AppIcons.play,
        ),
        if (saved) ...[
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: onOpenSaved,
            borderRadius: AppRadius.smAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.coachSavedWorkout,
                    size: CoachCardHeader.iconSize,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Gardée dans Mes modèles · Coach',
                      style: AppTypography.label.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ),
                  if (onOpenSaved != null)
                    const Icon(
                      AppIcons.chevronRight,
                      size: CoachCardHeader.iconSize,
                      color: AppColors.primaryLight,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String get _summary {
    final count = proposal.exercises.length;
    final exercises = count > 1 ? '$count exercices' : '$count exercice';
    return '$exercises · ${proposal.estimatedMinutes} min';
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
