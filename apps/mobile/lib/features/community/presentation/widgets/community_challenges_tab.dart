import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';

import '../../../../core/utilities/text_search.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/friend_challenge.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import '../providers/community_tab_state.dart';
import 'challenge_card.dart';
import 'community_flows.dart';
import 'community_gestures.dart';
import 'community_section.dart';
import 'friend_challenge/friend_challenge_gestures.dart';
import 'friend_challenge_card.dart';

/// L'onglet DÉFIS : les défis du mois, à progression COLLECTIVE, puis les
/// défis lancés entre amis.
class CommunityChallengesTab extends ConsumerWidget {
  const CommunityChallengesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(communityChallengesProvider);
    final friendChallenges = ref.watch(friendChallengesProvider);
    // Écoutés sans arbitrer : la feuille « Défier mes amis » a besoin de la
    // liste, déjà chargée à son ouverture — et un provider auto-disposé que
    // personne n'écoute se viderait avant.
    final friends = ref.watch(communityFriendsProvider);
    final query = ref.watch(communitySearchProvider) ?? '';

    return CommunityTabGate(
      sources: [challenges, friendChallenges],
      errorTitle: 'Défis indisponibles',
      offlineMessage:
          'Les défis vivent sur le serveur. Ils reviennent avec le réseau.',
      builder: (context) {
        final actions = ref.read(communityActionsProvider);
        final moderation = ref.read(communityModerationActionsProvider);
        final gestures = CommunityGestures(actions, moderation);
        final friendGestures = FriendChallengeGestures(actions, moderation);
        final monthly = [
          for (final challenge
              in challenges.valueOrNull ?? const <CommunityChallenge>[])
            if (matchesSearch(challenge.title, query)) challenge,
        ];
        final betweenFriends = [
          for (final challenge
              in friendChallenges.valueOrNull ?? const <FriendChallenge>[])
            if (matchesSearch(challenge.title, query)) challenge,
        ];

        final noMatch =
            query.trim().isNotEmpty &&
            monthly.isEmpty &&
            betweenFriends.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noMatch) const CommunityNoMatch('Aucun défi ne porte ce nom.'),
            ...communitySection('Défis du mois', [
              for (final challenge in monthly)
                ChallengeCard(
                  challenge: challenge,
                  onToggle: () => gestures.toggleChallenge(context, challenge),
                ),
            ]),
            ...communitySection('Défis entre amis', [
              // Le bouton d'abord, toujours : la section serait sinon muette
              // tant que personne n'a été défié, et rien ne dirait qu'on peut
              // l'être.
              AppButton(
                label: 'Défier mes amis',
                variant: AppButtonVariant.secondary,
                isExpanded: true,
                // Pas avant d'avoir la liste : ouverte trop tôt, ou sur une
                // liste en panne, la feuille dirait « pas encore d'ami » à
                // qui en a.
                onPressed: friends.hasValue
                    ? () => newFriendChallengeFlow(
                        context,
                        actions,
                        friends.requireValue,
                      )
                    : null,
              ),
              if (friends.hasError && !friends.hasValue)
                const CommunityNoMatch(
                  'Ta liste d’amis n’a pas pu se charger. Tire vers le bas '
                  'pour réessayer.',
                ),
              for (final challenge in betweenFriends)
                FriendChallengeCard(
                  challenge: challenge,
                  onOpen: () =>
                      context.push(AppRoutes.friendChallenge(challenge.id)),
                  onAccept: () => friendGestures.accept(context, challenge),
                  onDecline: () => friendGestures.leave(context, challenge),
                ),
            ]),
          ],
        );
      },
    );
  }
}
