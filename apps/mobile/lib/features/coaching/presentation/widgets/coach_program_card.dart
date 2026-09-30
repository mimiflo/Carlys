import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import 'coach_card_frame.dart';

/// Carte d'un PROGRAMME proposé par le coach : les réglages qu'il a choisis,
/// et le geste qui laisse Carlys construire le programme.
///
/// Sœur de la carte de séance, même surface : on ne doit pas avoir à
/// réapprendre ce qu'est une proposition. Le contenu du programme n'y figure
/// pas, et c'est honnête : il n'existe qu'une fois engendré.
class CoachProgramCard extends StatelessWidget {
  const CoachProgramCard({
    required this.proposal,
    required this.onOpen,
    required this.maxWidth,
    this.isBusy = false,
    super.key,
  });

  final CoachProgramProposal proposal;
  final VoidCallback onOpen;
  final double maxWidth;

  /// La génération est en cours : le bouton patiente au lieu d'en relancer
  /// une seconde.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return CoachCardFrame(
      maxWidth: maxWidth,
      children: [
        const CoachCardHeader(
          icon: AppIcons.programs,
          label: 'PROGRAMME PROPOSÉ',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          proposal.goal.label,
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          _rhythm,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          proposal.isAccepted
              ? 'Programme déjà créé.'
              : 'Carlys le construit avec ton niveau et ton matériel ; '
                    'tu le relis avant de l’activer.',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: proposal.isAccepted
              ? 'Voir le programme'
              : 'Créer ce programme',
          onPressed: onOpen,
          isLoading: isBusy,
          isExpanded: true,
          icon: AppIcons.programs,
        ),
      ],
    );
  }

  String get _rhythm {
    final sessions = proposal.weeklySessions;
    final perWeek = sessions > 1 ? '$sessions séances' : '$sessions séance';
    return '$perWeek par semaine · ${proposal.sessionMinutes} min';
  }
}
