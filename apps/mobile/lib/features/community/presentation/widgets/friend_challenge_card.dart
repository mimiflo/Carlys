import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/friend_challenge.dart';

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
    super.key,
  });

  final FriendChallenge challenge;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final moi = challenge.me;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.xs),
              const AppSectionLabel('Entre amis'),
              const Spacer(),
              Text(
                challenge.isOver
                    ? 'terminé'
                    : challenge.daysLeft <= 0
                    ? 'dernier jour'
                    : 'J−${challenge.daysLeft}',
                style: AppTypography.labelMono.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
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
            challenge.isPending
                ? '${challenge.creatorDisplayName} te défie · ${challenge.unit}'
                : 'Lancé par ${challenge.creatorDisplayName} · ${challenge.unit}',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          if (challenge.ranked.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final membre in challenge.ranked.take(3))
              _RankRow(member: membre, unit: challenge.unit),
            // Ma ligne, même hors du podium : un classement où l'on ne se
            // trouve pas ne motive personne.
            if (moi != null && moi.rank != null && moi.rank! > 3)
              _RankRow(member: moi, unit: challenge.unit),
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
  const _RankRow({required this.member, required this.unit});

  final FriendChallengeMember member;
  final String unit;

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
            '${formatThousands(member.contribution)} $unit',
            style: AppTypography.label.copyWith(color: couleur),
          ),
        ],
      ),
    );
  }
}
