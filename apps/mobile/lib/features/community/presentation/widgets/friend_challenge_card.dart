import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/friend_challenge.dart';
import 'friend_challenge/friend_challenge_wording.dart';

/// Un défi entre amis : qui mène, de combien, et ce qu'il reste à faire.
///
/// Le classement est INDIVIDUEL — c'est ce qui le sépare d'un défi
/// collectif, dont la carte ne montre qu'une barre de groupe. Il est donc
/// nommé, chiffré, et ma ligne y est mise en évidence : un classement où
/// l'on ne se trouve pas ne motive personne.
class FriendChallengeCard extends StatelessWidget {
  const FriendChallengeCard({
    required this.challenge,
    required this.onAccept,
    required this.onDecline,
    this.onOpen,
    super.key,
  });

  final FriendChallenge challenge;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Ouvre l'écran du défi (participants, règle, message). La carte entière
  /// y mène ; ses boutons gardent leur propre geste.
  final VoidCallback? onOpen;

  static const double _iconSize = 18;

  @override
  Widget build(BuildContext context) {
    final moi = challenge.me;

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.challengeOutline,
                size: _iconSize,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.xs),
              const AppSectionLabel('Entre amis'),
              const Spacer(),
              Text(
                friendChallengeCountdown(challenge),
                style: AppTypography.labelMono.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
              if (onOpen != null) ...[
                const SizedBox(width: AppSpacing.xxs),
                const Icon(
                  AppIcons.chevronRight,
                  size: _iconSize,
                  color: AppColors.darkTextTertiary,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            challenge.title,
            style: AppTypography.subheading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          Text(
            // Sans l'unité : chaque ligne du classement porte déjà la sienne
            // (« 12,4 km »), et « · mètres » la contredisait.
            friendChallengeOrigin(challenge),
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          if (challenge.ranked.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final membre in challenge.ranked.take(3))
              _RankRow(member: membre, metric: challenge.metric),
            // Ma ligne, même hors du podium : un classement où l'on ne se
            // trouve pas ne motive personne.
            if (moi != null && moi.rank != null && moi.rank! > 3)
              _RankRow(member: moi, metric: challenge.metric),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (challenge.isPending)
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Accepter',
                    size: AppButtonSize.small,
                    isExpanded: true,
                    onPressed: onAccept,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: AppButton(
                    label: 'Refuser',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    isExpanded: true,
                    onPressed: onDecline,
                  ),
                ),
              ],
            )
          else if (!challenge.isOver)
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Quitter',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: onDecline,
              ),
            ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.member, required this.metric});

  final FriendChallengeMember member;
  final ChallengeMetric metric;

  @override
  Widget build(BuildContext context) {
    final couleur = member.isMe
        ? AppColors.primaryLight
        : AppColors.darkTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${member.rank}',
              style: AppTypography.labelMono.copyWith(color: couleur),
            ),
          ),
          Expanded(
            child: Text(
              member.isMe ? 'Toi' : member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(color: couleur),
            ),
          ),
          Text(
            friendChallengeAmount(metric, member.contribution),
            style: AppTypography.label.copyWith(color: couleur),
          ),
        ],
      ),
    );
  }
}
