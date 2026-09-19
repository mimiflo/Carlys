import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/community_moderation.dart';
import '../../domain/entities/friend_challenge.dart';
import '../../domain/entities/league.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import 'blocked_user_card.dart';
import 'challenge_card.dart';
import 'community_gestures.dart';
import 'encouragement_tile.dart';
import 'friend_card.dart';
import 'friend_challenge_card.dart';
import 'friend_request_card.dart';
import 'friends_empty_card.dart';
import 'league_card.dart';
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
    required this.friendChallenges,
    required this.league,
    required this.blocked,
    required this.onNewFriendChallenge,
    required this.sharesProgress,
    required this.onAddFriend,
    super.key,
  });

  final List<FriendRequest>? requests;
  final List<Encouragement>? feed;
  final List<CommunityFriend>? friends;
  final List<CommunityChallenge>? challenges;
  final List<FriendChallenge>? friendChallenges;

  /// `null` tant que la ligue n'est pas chargée : la section s'efface.
  final League? league;
  final List<BlockedUser>? blocked;

  /// Ouvre la feuille « Défier mes amis ».
  final VoidCallback onNewFriendChallenge;

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
                  onBlock: () =>
                      gestures.blockEncouragementAuthor(context, encouragement),
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
        ..._section('Défis entre amis', [
          // Le bouton d'abord, toujours : la section serait sinon muette
          // tant que personne n'a été défié, et rien ne dirait qu'on peut
          // l'être.
          AppButton(
            label: 'Défier mes amis',
            variant: AppButtonVariant.secondary,
            isExpanded: true,
            onPressed: onNewFriendChallenge,
          ),
          ...?friendChallenges?.map<Widget>(
            (challenge) => FriendChallengeCard(
              challenge: challenge,
              onAccept: () =>
                  gestures.acceptFriendChallenge(context, challenge),
              onDecline: () =>
                  gestures.declineFriendChallenge(context, challenge),
            ),
          ),
        ]),
        // Après les défis, et avant la confidentialité : c'est le même
        // sujet — ce qu'on accepte de montrer, et à qui.
        ..._section('Ligue', _leagueSection(context, gestures)),
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
  /// La carte de ligue, ou rien tant qu'elle n'est pas chargée : la section
  /// s'efface plutôt que de poser un titre orphelin.
  List<Widget>? _leagueSection(
    BuildContext context,
    CommunityGestures gestures,
  ) {
    final chargee = league;
    if (chargee == null) {
      return null;
    }
    return [
      LeagueCard(
        league: chargee,
        onJoin: () => gestures.setLeagueJoined(context, joined: true),
        onLeave: () => gestures.setLeagueJoined(context, joined: false),
      ),
    ];
  }

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
