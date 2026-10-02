import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import 'coach_card_frame.dart';

/// Carte d'une séance que le coach a ENREGISTRÉE (« Ok crée-la ») : elle
/// existe, dans les modèles de séance, prête à relire et à lancer.
///
/// Sœur des cartes de proposition, même surface. Elle n'apparaît que sur la
/// preuve du serveur (le modèle écrit en base), jamais sur la foi du texte.
class CoachCreatedWorkoutCard extends StatelessWidget {
  const CoachCreatedWorkoutCard({
    required this.workout,
    required this.onOpen,
    required this.maxWidth,
    this.isBusy = false,
    super.key,
  });

  final CoachCreatedWorkout workout;

  /// Sans geste fourni, le bouton reste inactif plutôt que muet.
  final VoidCallback? onOpen;
  final double maxWidth;

  /// Ses modèles se rapatrient avant de l'ouvrir.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return CoachCardFrame(
      maxWidth: maxWidth,
      children: [
        const CoachCardHeader(
          icon: AppIcons.coachSavedWorkout,
          label: 'SÉANCE ENREGISTRÉE',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          workout.name,
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Dans tes séances, prête à lancer ou à retoucher.',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Ouvrir dans mes séances',
          onPressed: onOpen,
          isLoading: isBusy,
          isExpanded: true,
          icon: AppIcons.coachSavedWorkout,
        ),
      ],
    );
  }
}
