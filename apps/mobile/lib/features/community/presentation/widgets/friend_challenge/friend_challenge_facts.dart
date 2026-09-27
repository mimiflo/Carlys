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

    // Quatre colonnes à la taille d'origine ; deux rangées de deux dès que
    // le texte grandit : à quatre, « uniquement » se coupait en son milieu
    // dès le texte ×1,15 sur 390 points (« uniquemen / t »).
    final grid = MediaQuery.textScalerOf(context).scale(1) > _gridTextScale;
    final perRow = grid ? 2 : facts.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Mesuré ICI, hors de l'`IntrinsicHeight` des rangées : le corps
          // commun qui laisse le plus long mot des libellés tenir dans sa
          // colonne. Aucun mot ne se coupe, et les quatre gardent la même
          // taille.
          final cell =
              (constraints.maxWidth - (perRow - 1) * _dividerWidth) / perRow -
              2 * _Fact.inset;
          final labelStyle = AppWholeWordsText.fittedStyle(
            context,
            texts: [for (final (_, fact) in facts) fact.label],
            style: _Fact.baseLabelStyle,
            maxWidth: cell,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var start = 0; start < facts.length; start += perRow) ...[
                if (start > 0)
                  const Divider(
                    height: AppSpacing.md,
                    thickness: _dividerWidth,
                    color: AppColors.darkBorder,
                  ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var index = start;
                        index < start + perRow;
                        index++
                      ) ...[
                        if (index > start)
                          const VerticalDivider(
                            width: _dividerWidth,
                            thickness: _dividerWidth,
                            color: AppColors.darkBorder,
                          ),
                        Expanded(
                          child: _Fact(
                            icon: facts[index].$1,
                            fact: facts[index].$2,
                            labelStyle: labelStyle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Au-delà de ce facteur de texte, les faits passent en deux rangées.
  static const double _gridTextScale = 1.1;
  static const double _dividerWidth = 1;

  static IconData _metricIcon(ChallengeMetric metric) => switch (metric) {
    ChallengeMetric.workouts => AppIcons.workout,
    ChallengeMetric.activeSeconds => AppIcons.timer,
    ChallengeMetric.distanceMeters => AppIcons.trainingDay,
    ChallengeMetric.quizCorrect => AppIcons.academyOutline,
  };
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.fact,
    required this.labelStyle,
  });

  final IconData icon;
  final FriendChallengeFact fact;

  /// Le style du libellé, ajusté par la rangée à la largeur des colonnes.
  final TextStyle labelStyle;

  static const double _iconSize = 26;
  static const double inset = AppSpacing.xxs;
  static final TextStyle baseLabelStyle = AppTypography.label.copyWith(
    color: AppColors.darkTextSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${fact.value} ${fact.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: inset),
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
              style: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}
