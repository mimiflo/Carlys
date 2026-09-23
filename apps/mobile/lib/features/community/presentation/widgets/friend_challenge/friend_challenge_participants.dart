import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/friend_challenge.dart';
import 'friend_challenge_wording.dart';

/// Qui est dans le défi, et où en est chacun de sa réponse : à l'origine,
/// dans le défi, en attente.
///
/// Des INITIALES, pas des photos : Carlys n'a pas de photo de profil. Et
/// pas de bouton « Ajouter des amis » : les invités se choisissent à la
/// création, et un défi ne s'élargit pas en route (arbitrage du
/// 23 septembre 2026). Qui a refusé ou quitté n'est plus un participant.
class FriendChallengeParticipants extends StatelessWidget {
  const FriendChallengeParticipants({required this.challenge, super.key});

  final FriendChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final participants = challenge.participants;

    return Semantics(
      container: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Participants (${participants.length})',
                style: AppTypography.heading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Jusqu'à dix personnes : la rangée défile plutôt que de passer
            // à la ligne, et garde chaque visage à la même place.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final member in participants) ...[
                    _Participant(member: member),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Participant extends StatelessWidget {
  const _Participant({required this.member});

  final FriendChallengeMember member;

  static const double _avatarSize = 56;
  static const double _width = 96;

  @override
  Widget build(BuildContext context) {
    final name = member.isMe ? 'Toi' : member.displayName;
    final status = friendChallengeMemberStatus(member);
    final tone = member.isCreator
        ? AppPillTone.primary
        : member.status == FriendChallengeMemberStatus.accepted
        ? AppPillTone.success
        : AppPillTone.accent;

    return Semantics(
      container: true,
      label: '$name, $status',
      excludeSemantics: true,
      child: SizedBox(
        width: _width,
        child: Column(
          children: [
            AppInitialAvatar(
              name: member.displayName,
              size: _avatarSize,
              highlighted: member.isMe,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AppPill(label: status, tone: tone),
            ),
          ],
        ),
      ),
    );
  }
}
