import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/community_controllers.dart';
import '../widgets/add_friend_sheet.dart';
import '../widgets/challenge_card.dart';
import '../widgets/encouragement_tile.dart';
import '../widgets/friend_card.dart';
import '../widgets/friend_request_card.dart';
import '../widgets/privacy_card.dart';

/// Communauté — les autres, comme moteur.
///
/// Quatre étages : les demandes d'ami reçues, le fil des encouragements, les
/// amis (progression visible SEULEMENT si partagée — décision du serveur),
/// les défis à progression COLLECTIVE. Et en pied d'écran, le réglage de
/// confidentialité : partager sa progression, ou ne montrer que son nom.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  Future<void> _addFriend(
    BuildContext context,
    CommunityActions actions,
  ) async {
    final email = await showAddFriendSheet(context);
    if (email == null) {
      return;
    }
    await actions.sendFriendRequest(email);
    if (context.mounted) {
      // Volontairement opaque, comme le serveur : on ne confirme jamais
      // qu'une adresse a un compte.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Si ce compte existe, il recevra ta demande.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(encouragementsProvider);
    final friends = ref.watch(communityFriendsProvider);
    final requests = ref.watch(friendRequestsProvider);
    final challenges = ref.watch(communityChallengesProvider);
    final sharesProgress = ref.watch(sharesProgressProvider);
    final actions = ref.read(communityActionsProvider);
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    final isEmpty = (feed.valueOrNull?.isEmpty ?? true) &&
        (friends.valueOrNull?.isEmpty ?? true) &&
        (requests.valueOrNull?.isEmpty ?? true) &&
        (challenges.valueOrNull?.isEmpty ?? true);
    final loaded = !feed.isLoading &&
        !friends.isLoading &&
        !requests.isLoading &&
        !challenges.isLoading;
    // Une erreur n'est PAS un écran vide : « personne ici » serait un
    // mensonge si le serveur a simplement refusé de répondre.
    final hasError = feed.hasError ||
        friends.hasError ||
        requests.hasError ||
        challenges.hasError;
    // PREMIER chargement seulement : pendant un rafraîchissement, Riverpod
    // conserve la valeur précédente (`valueOrNull` reste peuplé) et l'écran
    // continue de la montrer — remplacer la liste par un indicateur ferait
    // sauter la position de lecture à chaque écriture.
    final hasData = feed.hasValue ||
        friends.hasValue ||
        requests.hasValue ||
        challenges.hasValue;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          MediaQuery.paddingOf(context).top + AppSpacing.gapSection,
          AppSpacing.gutter,
          bottomInset + AppSpacing.gapSection,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Communauté',
                  style: AppTypography.display
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
              ),
              IconButton(
                onPressed: () => _addFriend(context, actions),
                tooltip: 'Ajouter un ami',
                icon: const Icon(
                  Icons.person_add_alt_1_outlined,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'On tient plus longtemps à plusieurs.',
            style:
                AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
          ),
          const SizedBox(height: AppSpacing.gapRow),
          if (hasError)
            AppErrorState(
              title: 'Communauté indisponible',
              message: 'Impossible de charger le fil pour le moment.',
              onRetry: () {
                ref
                  ..invalidate(encouragementsProvider)
                  ..invalidate(communityFriendsProvider)
                  ..invalidate(friendRequestsProvider)
                  ..invalidate(communityChallengesProvider);
              },
            )
          else if (!hasData)
            const AppLoadingIndicator()
          else if (loaded && isEmpty)
            AppEmptyState(
              icon: Icons.group_outlined,
              title: 'Personne ici pour l’instant',
              message: 'Ajoute un premier ami par son adresse e-mail : vous '
                  'verrez vos séries, et vous pourrez vous encourager.',
              actionLabel: 'Ajouter un ami',
              onAction: () => _addFriend(context, actions),
            )
          else ...[
            ..._section(
              'Demandes reçues',
              requests.valueOrNull
                  ?.map<Widget>(
                    (request) => FriendRequestCard(
                      request: request,
                      onAccept: () =>
                          actions.respondToRequest(request.id, accept: true),
                      onDecline: () =>
                          actions.respondToRequest(request.id, accept: false),
                    ),
                  )
                  .toList(),
            ),
            ..._section(
              'Encouragements',
              feed.valueOrNull
                  ?.map<Widget>(
                    (encouragement) =>
                        EncouragementTile(encouragement: encouragement),
                  )
                  .toList(),
            ),
            ..._section(
              'Amis',
              friends.valueOrNull
                  ?.map<Widget>(
                    (friend) => FriendCard(
                      friend: friend,
                      onEncourage: () => actions.encourage(
                        friend.id,
                        'Continue, ça paie !',
                      ),
                    ),
                  )
                  .toList(),
            ),
            ..._section(
              'Défis',
              challenges.valueOrNull
                  ?.map<Widget>(
                    (challenge) => ChallengeCard(
                      challenge: challenge,
                      onToggle: () => actions.toggleChallenge(challenge),
                    ),
                  )
                  .toList(),
            ),
            ..._section('Confidentialité', [
              PrivacyCard(
                sharesProgress: sharesProgress.valueOrNull,
                onChanged: (value) => actions.setSharesProgress(value: value),
              ),
            ]),
          ],
        ],
      ),
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
