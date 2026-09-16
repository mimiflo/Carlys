import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/academy_journey.dart';

/// L'entrée du Parcours sur l'écran Academy : où on en est, où reprendre.
///
/// La carte OUVRE la vue des six étapes ; le bouton reprend directement
/// l'étape courante — deux gestes, deux intentions : voir le chemin, ou
/// continuer à marcher.
class JourneyEntryCard extends StatelessWidget {
  const JourneyEntryCard({
    required this.progress,
    required this.onOpen,
    required this.onResume,
    super.key,
  });

  final JourneyProgress progress;

  /// Ouvre la vue d'ensemble des étapes.
  final VoidCallback onOpen;

  /// Ouvre l'étape courante. Ignoré quand le parcours est terminé.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final courante = progress.etapeCourante;
    final stage = courante == null ? null : academyJourney[courante];
    final jamaisCommence =
        courante == 0 && progress.parEtape.first.abordees == 0;

    return Semantics(
      button: true,
      label: stage == null
          ? 'Parcours guidé terminé, six étapes sur six'
          : 'Parcours guidé, étape ${stage.rang} sur ${academyJourney.length}'
                ', ${stage.nom}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.padCard),
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.darkBorder),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: AppSectionLabel('Parcours guidé')),
                  Text(
                    '${progress.etapesTerminees} / ${academyJourney.length} '
                    'étapes',
                    style: AppTypography.resized(AppTypography.labelMono, 11)
                        .copyWith(
                          color: progress.termine
                              ? AppColors.accent
                              : AppColors.darkTextTertiary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                stage == null
                    ? 'Terminé. Chaque étape reste relisible.'
                    : 'Étape ${stage.rang} · ${stage.nom}',
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              if (stage != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  stage.description,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: jamaisCommence ? 'Commencer' : 'Reprendre',
                  size: AppButtonSize.small,
                  onPressed: onResume,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
