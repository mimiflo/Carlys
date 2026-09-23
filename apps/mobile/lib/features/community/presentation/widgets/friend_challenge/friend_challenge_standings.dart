import 'package:flutter/material.dart';

import '../../../../../core/utilities/formatting.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/friend_challenge.dart';
import '../league/league_wording.dart';
import 'friend_challenge_wording.dart';

/// Le classement du défi : ceux qui ont accepté, du premier au dernier, et
/// MA ligne en évidence. Avec un objectif commun, chacun voit qui l'a
/// atteint ; sans objectif, celui qui en fait le plus mène.
///
/// Le rang vient du serveur (ex æquo au même rang) : on ne le recalcule pas.
class FriendChallengeStandings extends StatelessWidget {
  const FriendChallengeStandings({required this.challenge, super.key});

  final FriendChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final ranked = challenge.ranked;
    final me = challenge.me;
    final myRank = me?.rank;

    return Semantics(
      container: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                challenge.isOver ? 'Classement final' : 'Classement',
                style: AppTypography.heading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            if (challenge.isOver && myRank != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Tu termines à la ${leaguePlace(myRank)}.',
                style: AppTypography.body.copyWith(
                  color: AppColors.primaryLight,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (ranked.isEmpty)
              Text(
                'Personne n’est encore classé : on y entre en acceptant.',
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              )
            else
              for (final member in ranked) ...[
                _StandingRow(member: member, challenge: challenge),
                const SizedBox(height: AppSpacing.xxs),
              ],
          ],
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.member, required this.challenge});

  final FriendChallengeMember member;
  final FriendChallenge challenge;

  static const double _rankWidth = 28;
  static const double _avatarSize = 36;
  static const double _checkSize = 18;

  @override
  Widget build(BuildContext context) {
    final me = member.isMe;
    final name = me ? 'Toi' : member.displayName;
    final target = challenge.target;
    final reached = target != null && member.contribution >= target;
    final amount = friendChallengeAmount(challenge.metric, member.contribution);
    // Avec un objectif, la ligne dit où l'on en est de lui : « 2 / 5
    // séances » — l'unité une seule fois quand elle se compte.
    final counted =
        challenge.metric == ChallengeMetric.workouts ||
        challenge.metric == ChallengeMetric.quizCorrect;
    final value = target == null
        ? amount
        : '${counted ? formatThousands(member.contribution) : amount}'
              ' / ${friendChallengeAmount(challenge.metric, target)}';

    return Semantics(
      container: true,
      label: [
        leaguePlace(member.rank ?? 0),
        name,
        amount,
        if (reached) 'objectif atteint',
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: me
            ? const BoxDecoration(
                color: AppColors.primaryBadgeBg,
                borderRadius: AppRadius.mdAll,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.primaryBadgeBorder),
                ),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: _rankWidth,
              child: Text(
                '${member.rank}',
                style: AppTypography.subheading.copyWith(
                  color: me
                      ? AppColors.primaryLight
                      : AppColors.darkTextPrimary,
                ),
              ),
            ),
            AppInitialAvatar(
              name: member.displayName,
              size: _avatarSize,
              highlighted: me,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLarge.copyWith(
                  color: me
                      ? AppColors.darkTextPrimary
                      : AppColors.darkTextSecondary,
                ),
              ),
            ),
            if (reached) ...[
              const Icon(
                AppIcons.checkCircle,
                size: _checkSize,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.xxs),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: AppTypography.subheading.copyWith(
                    color: me
                        ? AppColors.primaryLight
                        : AppColors.darkTextPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
