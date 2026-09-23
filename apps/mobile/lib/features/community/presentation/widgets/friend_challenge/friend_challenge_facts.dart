import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/friend_challenge.dart';
import 'friend_challenge_wording.dart';

/// La rangée de faits sous l'en-tête : l'objectif, la durée, ce qui compte,
/// et qui peut y entrer.
///
/// La maquette y mettait « +150 points » : un défi entre amis ne rapporte
/// rien (principe 5), la tuile dit donc la DURÉE — un fait, pas une
/// promesse.
class FriendChallengeFacts extends StatelessWidget {
  const FriendChallengeFacts({required this.challenge, super.key});

  final FriendChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final facts = <(IconData, FriendChallengeFact)>[
      (AppIcons.objective, friendChallengeGoal(challenge)),
      (AppIcons.calendarOutline, friendChallengeDuration(challenge)),
      (_metricIcon(challenge.metric), friendChallengeCounts(challenge.metric)),
      (AppIcons.community, (value: 'Amis', label: 'uniquement')),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < facts.length; index++) ...[
              if (index > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.darkBorder,
                ),
              Expanded(
                child: _Fact(icon: facts[index].$1, fact: facts[index].$2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _metricIcon(ChallengeMetric metric) => switch (metric) {
    ChallengeMetric.workouts => AppIcons.workout,
    ChallengeMetric.activeSeconds => AppIcons.timer,
    ChallengeMetric.distanceMeters => AppIcons.trainingDay,
    ChallengeMetric.quizCorrect => AppIcons.academyOutline,
  };
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.fact});

  final IconData icon;
  final FriendChallengeFact fact;

  static const double _iconSize = 26;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${fact.value} ${fact.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        child: Column(
          children: [
            Icon(icon, size: _iconSize, color: AppColors.primaryLight),
            const SizedBox(height: AppSpacing.xs),
            // La valeur se réduit plutôt que de déborder : quatre colonnes
            // sur la largeur d'un téléphone, en grand texte.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                fact.value,
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              fact.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
