import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/community_moderation.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import 'blocked_user_card.dart';
import 'challenge_card.dart';
import 'community_gestures.dart';
import 'encouragement_tile.dart';
import 'friend_card.dart';
import 'friend_request_card.dart';
import 'friends_empty_card.dart';
import 'privacy_card.dart';

/// Les étages de l'écran Communauté, une fois les données là : demandes
/// reçues, fil, amis, défis, puis la confidentialité et les personnes
/// bloquées. Une section s'efface quand sa liste est vide (pas de titre
/// orphelin) ; chaque geste passe par [CommunityGestures], qui confirme,
/// appelle et rend compte.
class CommunitySections extends ConsumerWidget {
  const CommunitySections({
    required this.requests,
    required this.feed,
    required this.friends,
    required this.challenges,
    required this.blocked,
    required this.sharesProgress,
    required this.onAddFriend,
    super.key,
  });

  final List<FriendRequest>? requests;
  final List<Encouragement>? feed;
  final List<CommunityFriend>? friends;
  final List<CommunityChallenge>? challenges;
  final List<BlockedUser>? blocked;

  /// `null` tant que la préférence n'est pas chargée.
  final bool? sharesProgress;

  /// Ouvre la feuille « Ajouter un ami » : le geste qui débloque tout, offert
  /// dans la section « Amis » tant qu'elle est vide.
  final VoidCallback onAddFriend;

  /// Aucun ami ET aucune demande en attente : la section « Amis » invite au
  /// premier ajout au lieu de disparaître.
  bool get _invitesFirstFriend =>
      (friends?.isEmpty ?? false) && (requests?.isEmpty ?? true);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestures = CommunityGestures(
      ref.read(communityActionsProvider),
      ref.read(communityModerationActionsProvider),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._section(
          'Demandes reçues',
          requests
              ?.map<Widget>(
                (request) => FriendRequestCard(
                  request: request,
                  onAccept: () =>
                      gestures.respondToRequest(context, request, accept: true),
                  onDecline: () => gestures.respondToRequest(
                    context,
                    request,
                    accept: false,
                  ),
                ),
              )
              .toList(),
        ),
        ..._section(
          'Encouragements',
          feed
              ?.map<Widget>(
                (encouragement) => EncouragementTile(
                  encouragement: encouragement,
                  onDelete: () =>
                      gestures.deleteEncouragement(context, encouragement),
                  onReport: () =>
                      gestures.reportEncouragement(context, encouragement),
                ),
              )
              .toList(),
        ),
        ..._section(
          'Amis',
          _invitesFirstFriend
              ? [FriendsEmptyCard(onAddFriend: onAddFriend)]
              : friends
                    ?.map<Widget>(
                      (friend) => FriendCard(
                        friend: friend,
                        onEncourage: () => gestures.encourage(context, friend),
                        onRemove: () => gestures.removeFriend(context, friend),
                        onBlock: () => gestures.blockFriend(context, friend),
                        onReport: () => gestures.reportFriend(context, friend),
                      ),
                    )
                    .toList(),
        ),
        ..._section(
          'Défis',
          challenges
              ?.map<Widget>(
                (challenge) => ChallengeCard(
                  challenge: challenge,
                  onToggle: () => gestures.toggleChallenge(context, challenge),
                ),
              )
              .toList(),
        ),
        ..._section('Confidentialité', [
          PrivacyCard(
            sharesProgress: sharesProgress,
            onChanged: (value) =>
                gestures.setSharesProgress(context, value: value),
          ),
        ]),
        ..._section(
          'Personnes bloquées',
          blocked
              ?.map<Widget>(
                (user) => BlockedUserCard(
                  user: user,
                  onUnblock: () => gestures.unblock(context, user),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// Une section titrée, absente si sa liste est vide : pas de titre orphelin.
  List<Widget> _section(String title, List<Widget>? children) {
    if (children == null || children.isEmpty) {
      return const [];
    }
    return [
      AppSectionLabel(title),
      const SizedBox(height: AppSpacing.xs),
      for (final child in children) ...[
        child,
        const SizedBox(height: AppSpacing.gapRow),
      ],
      const SizedBox(height: AppSpacing.xs),
    ];
  }
}
