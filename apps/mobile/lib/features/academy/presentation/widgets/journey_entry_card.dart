import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/summit_illustration.dart';
import '../../domain/academy_journey.dart';
import 'journey_stepper.dart';

/// L'entrée du Parcours sur l'écran Academy (maquette d'octobre 2026) : où
/// on en est, les six étapes, et deux gestes — reprendre l'étape courante,
/// ou voir le chemin entier — sur le sommet au fanion.
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

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Le texte s'arrête avant la partie pleine de l'image, comme dans
          // `IllustratedBanner` : agrandi, il passe à la ligne au lieu de
          // glisser sur la lune.
          final textMaxWidth =
              SummitIllustration.opaqueFromFor(constraints.maxWidth) +
              SummitIllustration.wideTextShift -
              AppSpacing.padCard;
          return Stack(
            children: [
              const Positioned(
                top: 0,
                bottom: 0,
                left: SummitIllustration.wideTextShift,
                right: -SummitIllustration.wideTextShift,
                child: SummitIllustration(),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.padCard),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: textMaxWidth),
                      child: _Wording(progress: progress, stage: stage),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: textMaxWidth),
                      child: JourneyStepper(progress: progress),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (stage != null)
                          AppButton(
                            label: jamaisCommence ? 'Commencer' : 'Reprendre',
                            size: AppButtonSize.small,
                            onPressed: onResume,
                          ),
                        TextButton.icon(
                          onPressed: onOpen,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(AppIcons.chevronRight),
                          label: const Text('Voir le parcours'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryLight,
                            textStyle: AppTypography.subheading,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Wording extends StatelessWidget {
  const _Wording({required this.progress, required this.stage});

  final JourneyProgress progress;
  final JourneyStage? stage;

  @override
  Widget build(BuildContext context) {
    final stage = this.stage;
    return Semantics(
      label: stage == null
          ? 'Parcours guidé terminé, six étapes sur six'
          : 'Parcours guidé, étape ${stage.rang} sur ${academyJourney.length}'
                ', ${stage.nom}. ${stage.description}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionLabel('Parcours guidé'),
          const SizedBox(height: AppSpacing.sm),
          AppWholeWordsText(
            stage == null
                ? 'Terminé. Chaque étape reste relisible.'
                : 'Étape ${stage.rang} · ${stage.nom}',
            style: AppTypography.title.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          if (stage != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              stage.description,
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
