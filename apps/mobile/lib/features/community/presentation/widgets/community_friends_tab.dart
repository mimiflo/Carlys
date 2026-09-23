import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/text_search.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/community_moderation.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import '../providers/community_tab_state.dart';
import 'blocked_user_card.dart';
import 'community_flows.dart';
import 'community_gestures.dart';
import 'community_section.dart';
import 'encouragement_tile.dart';
import 'friend_card.dart';
import 'friend_request_card.dart';
import 'friends_empty_card.dart';
import 'privacy_card.dart';

/// L'onglet AMIS : les demandes reçues, le fil des encouragements, les amis
/// (progression visible SEULEMENT si partagée — décision du serveur), puis
/// ce qu'on accepte de montrer et les personnes bloquées.
class CommunityFriendsTab extends ConsumerWidget {
  const CommunityFriendsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider);
    final feed = ref.watch(encouragementsProvider);
    final friends = ref.watch(communityFriendsProvider);
    // Les blocages comptent comme une donnée : un compte qui n'a plus que
    // des personnes bloquées n'est pas « vide », il doit pouvoir débloquer.
    final blocked = ref.watch(blockedUsersProvider);
    final sharesProgress = ref.watch(sharesProgressProvider);
    final query = ref.watch(communitySearchProvider) ?? '';

    return CommunityTabGate(
      sources: [requests, feed, friends, blocked],
      errorTitle: 'Communauté indisponible',
      offlineMessage:
          'Les amis et les encouragements vivent sur le serveur. Reviens '
          'quand le réseau est là.',
      builder: (context) {
        final actions = ref.read(communityActionsProvider);
        final gestures = CommunityGestures(
          actions,
          ref.read(communityModerationActionsProvider),
        );
        final sources = [requests, feed, friends, blocked];
        final nothingToShow = sources.every(
          (source) => source.valueOrNull?.isEmpty ?? true,
        );
        final privacy = communitySection('Confidentialité', [
          PrivacyCard(
            sharesProgress: sharesProgress.valueOrNull,
            onChanged: (value) =>
                gestures.setSharesProgress(context, value: value),
          ),
        ]);
        if (nothingToShow && query.trim().isEmpty) {
          // « Personne ici » ne se dit qu'une fois TOUT lu : une source
          // encore en vol n'est pas une liste vide, et un ami chargé une
          // seconde plus tard aurait démenti l'écran.
          if (!sources.every((source) => source.hasValue)) {
            return const AppLoadingIndicator();
          }
          // Hors ligne, c'est l'état d'erreur du portail qui parle, jamais
          // « personne ici ». Et le réglage de partage reste là : un compte
          // neuf doit pouvoir décider AVANT son premier ami de ce qu'il
          // montrera.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppEmptyState(
                icon: AppIcons.communityOutline,
                title: 'Personne ici pour l’instant',
                message: FriendsEmptyCard.invitation,
                actionLabel: 'Ajouter un ami',
                onAction: () => addFriendFlow(context, actions),
              ),
              const SizedBox(height: AppSpacing.gapSection),
              ...privacy,
            ],
          );
        }

        final searching = query.trim().isNotEmpty;
        final pending = [
          for (final request in requests.valueOrNull ?? const <FriendRequest>[])
            if (matchesSearch(request.fromDisplayName, query)) request,
        ];
        final words = [
          for (final encouragement
              in feed.valueOrNull ?? const <Encouragement>[])
            if (matchesSearch(encouragement.fromName, query)) encouragement,
        ];
        final shown = [
          for (final friend in friends.valueOrNull ?? const <CommunityFriend>[])
            if (matchesSearch(friend.displayName, query)) friend,
        ];
        final hidden = [
          for (final user in blocked.valueOrNull ?? const <BlockedUser>[])
            if (matchesSearch(user.displayName, query)) user,
        ];
        // Aucun ami ET aucune demande en attente : la section « Amis » invite
        // au premier ajout au lieu de disparaître — sauf pendant une
        // recherche, où elle ne répondrait pas à la question posée.
        final invitesFirstFriend =
            !searching &&
            (friends.valueOrNull?.isEmpty ?? false) &&
            (requests.valueOrNull?.isEmpty ?? true);
        final noMatch =
            searching &&
            pending.isEmpty &&
            words.isEmpty &&
            shown.isEmpty &&
            hidden.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noMatch)
              const CommunityNoMatch(
                'Personne ne s’appelle ainsi parmi tes amis.',
              ),
            ...communitySection('Demandes reçues', [
              for (final request in pending)
                FriendRequestCard(
                  request: request,
                  onAccept: () =>
                      gestures.respondToRequest(context, request, accept: true),
                  onDecline: () => gestures.respondToRequest(
                    context,
                    request,
                    accept: false,
                  ),
                ),
            ]),
            ...communitySection('Encouragements', [
              for (final encouragement in words)
                EncouragementTile(
                  encouragement: encouragement,
                  onDelete: () =>
                      gestures.deleteEncouragement(context, encouragement),
                  onBlock: () =>
                      gestures.blockEncouragementAuthor(context, encouragement),
                  onReport: () =>
                      gestures.reportEncouragement(context, encouragement),
                ),
            ]),
            ...communitySection('Amis', [
              if (invitesFirstFriend)
                FriendsEmptyCard(
                  onAddFriend: () => addFriendFlow(context, actions),
                )
              else
                for (final friend in shown)
                  FriendCard(
                    friend: friend,
                    onEncourage: () => gestures.encourage(context, friend),
                    onRemove: () => gestures.removeFriend(context, friend),
                    onBlock: () => gestures.blockFriend(context, friend),
                    onReport: () => gestures.reportFriend(context, friend),
                  ),
            ]),
            // Un réglage n'est pas un prénom : pendant une recherche, il
            // n'a rien à faire dans les résultats.
            if (!searching) ...privacy,
            ...communitySection('Personnes bloquées', [
              for (final user in hidden)
                BlockedUserCard(
                  user: user,
                  onUnblock: () => gestures.unblock(context, user),
                ),
            ]),
          ],
        );
      },
    );
  }
}
