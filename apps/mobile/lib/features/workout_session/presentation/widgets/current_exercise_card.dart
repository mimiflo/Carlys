import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import 'workout_progress_segments.dart';

/// La carte de l'exercice en cours : son nom, le rang de la série à faire
/// (« Série 3 sur 4 ») et une barre par série de l'exercice.
///
/// Le rang vient du PROGRAMME quand la séance en suit un ([setRank],
/// [setsInExercise]) : une série passée fait avancer le rang sans compter
/// parmi les faites. Sans programme, c'est le rang de la prochaine saisie,
/// sans total — une séance libre ne prévoit rien.
class CurrentExerciseCard extends StatelessWidget {
  const CurrentExerciseCard({
    required this.name,
    required this.doneSets,
    required this.upcomingSets,
    this.setRank,
    this.setsInExercise,
    super.key,
  });

  final String name;

  /// Séries déjà enregistrées sur l'exercice.
  final int doneSets;

  /// Séries prévues restant APRÈS celle en cours de saisie.
  final int upcomingSets;

  final int? setRank;
  final int? setsInExercise;

  @override
  Widget build(BuildContext context) {
    final total = setsInExercise;
    final rank = setRank ?? doneSets + 1;
    final rankLabel = total == null
        ? 'Série ${formatThousands(rank)}'
        : 'Série ${formatThousands(rank)} sur ${formatThousands(total)}';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.padCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXERCICE EN COURS',
                      style: AppTypography.labelMono.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Semantics(
                      header: true,
                      child: Text(
                        name,
                        style: AppTypography.title.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      rankLabel,
                      style: AppTypography.body.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AppIconBadge(icon: AppIcons.workout, size: 56),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          WorkoutProgressSegments(completed: doneSets, planned: upcomingSets),
        ],
      ),
    );
  }
}
