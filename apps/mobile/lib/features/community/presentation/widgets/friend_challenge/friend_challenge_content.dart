import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/friend_challenge.dart';
import 'friend_challenge_gestures.dart';
import 'friend_challenge_hero.dart';
import 'friend_challenge_notes.dart';
import 'friend_challenge_participants.dart';
import 'friend_challenge_standings.dart';

/// Le corps de l'écran d'un défi entre amis, une fois lu : l'en-tête, les
/// participants, le classement, la règle et le message, puis la réponse à
/// l'invitation quand elle est attendue.
///
/// Quitter un défi COMMENCÉ vit dans le menu de l'en-tête, pas ici : le bas
/// de l'écran appartient à la décision qu'on attend de moi, et une fois
/// dans le défi, il n'y en a plus.
class FriendChallengeContent extends StatelessWidget {
  const FriendChallengeContent({
    required this.challenge,
    required this.gestures,
    required this.onLeft,
    super.key,
  });

  final FriendChallenge challenge;
  final FriendChallengeGestures gestures;

  /// Suit un refus abouti : l'écran se referme.
  final VoidCallback onLeft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FriendChallengeHero(challenge: challenge),
        const SizedBox(height: AppSpacing.gapRow),
        FriendChallengeParticipants(challenge: challenge),
        const SizedBox(height: AppSpacing.gapRow),
        FriendChallengeStandings(challenge: challenge),
        const SizedBox(height: AppSpacing.gapRow),
        FriendChallengeNotes(challenge: challenge),
        if (challenge.isPending && !challenge.isOver) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Accepter le défi',
            icon: AppIcons.check,
            isExpanded: true,
            onPressed: () => gestures.accept(context, challenge),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Refuser',
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            onPressed: () => gestures.leave(context, challenge, onLeft: onLeft),
          ),
        ],
      ],
    );
  }
}
