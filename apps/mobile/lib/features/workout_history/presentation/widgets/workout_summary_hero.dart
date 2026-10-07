import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/summit_illustration.dart';
import '../../../workout_session/domain/entities/workout.dart';

/// Le haut du bilan : « Séance terminée ! », le nom de la séance et un mot
/// d'encouragement, devant le sommet au fanion (maquette d'octobre 2026).
///
/// Une séance terminée n'est pas un franchissement de titre : la carte reste
/// au VIOLET de l'appli, le dégradé de marque est réservé aux célébrations.
class WorkoutSummaryHero extends StatelessWidget {
  const WorkoutSummaryHero({required this.session, super.key});

  final WorkoutInfo session;

  /// Le texte s'arrête où le sommet devient plein.
  static const double textWidthFactor = 0.64;

  @override
  Widget build(BuildContext context) {
    final completed = session.status == WorkoutStatus.completed;
    final name = session.name ?? session.templateName ?? 'Séance libre';
    // Provenance de la séance : dénormalisée au lancement, donc lisible pour
    // toujours — même modèle renommé ou supprimé depuis.
    final template = session.templateName;
    final origin = template != null && template != name ? template : null;

    return Material(
      color: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            const Positioned(
              top: 0,
              bottom: 0,
              left: SummitIllustration.wideTextShift,
              right: -SummitIllustration.wideTextShift,
              child: SummitIllustration(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: AppSpacing.touchTarget,
                          height: AppSpacing.touchTarget,
                          decoration: const BoxDecoration(
                            gradient: AppColors.cta,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            completed ? AppIcons.check : AppIcons.history,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: AppPill(
                          label: session.status.label,
                          tone: completed
                              ? AppPillTone.success
                              : AppPillTone.neutral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * textWidthFactor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            completed ? 'Séance terminée !' : name,
                            style: AppTypography.title.copyWith(
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                        ),
                        if (completed)
                          Text(
                            name,
                            style: AppTypography.subheading.copyWith(
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                        if (origin != null)
                          Text(
                            'Modèle · $origin',
                            style: AppTypography.label.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          completed
                              ? 'Une séance de plus vers ton objectif.'
                              : 'Ce qui a été fait compte quand même.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
