import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import '../widgets/add_friend_sheet.dart';
import '../widgets/community_feedback.dart';
import '../widgets/community_sections.dart';

/// Communauté — les autres, comme moteur.
///
/// Quatre étages : les demandes d'ami reçues, le fil des encouragements, les
/// amis (progression visible SEULEMENT si partagée — décision du serveur),
/// les défis à progression COLLECTIVE. Et en pied d'écran, le réglage de
/// confidentialité : partager sa progression, ou ne montrer que son nom.
///
/// L'écran ne fait que trancher entre erreur, premier chargement, vide et
/// données ; les sections et leurs gestes vivent dans [CommunitySections].
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  Future<void> _addFriend(
    BuildContext context,
    CommunityActions actions,
  ) async {
    final input = await showAddFriendSheet(context);
    if (input == null || !context.mounted) {
      return;
    }
    // Deux registres de confirmation, à dessein : une ADRESSE reste opaque
    // (le serveur ne révèle jamais qu'elle a un compte) ; un CODE se partage
    // volontairement, on confirme donc par le prénom — ou l'on dit
    // franchement qu'il ne mène nulle part.
    await runCommunityGesture(context, () async {
      return switch (input) {
        AddFriendByEmail(:final email) => await () async {
          await actions.sendFriendRequest(email);
          return 'Si ce compte existe, il recevra ta demande.';
        }(),
        AddFriendByCode(:final code) => switch (await actions
            .sendFriendRequestByCode(code)) {
          final String name => 'Demande envoyée à $name.',
          null => 'Ce code ne mène à personne. Vérifie-le avec ton ami.',
        },
      };
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(encouragementsProvider);
    final friends = ref.watch(communityFriendsProvider);
    final requests = ref.watch(friendRequestsProvider);
    final challenges = ref.watch(communityChallengesProvider);
    // Les blocages comptent comme une donnée : un compte qui n'a plus que
    // des personnes bloquées n'est pas « vide », il doit pouvoir débloquer.
    final blocked = ref.watch(blockedUsersProvider);
    final sharesProgress = ref.watch(sharesProgressProvider);
    final actions = ref.read(communityActionsProvider);
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    final isEmpty =
        (feed.valueOrNull?.isEmpty ?? true) &&
        (friends.valueOrNull?.isEmpty ?? true) &&
        (requests.valueOrNull?.isEmpty ?? true) &&
        (challenges.valueOrNull?.isEmpty ?? true) &&
        (blocked.valueOrNull?.isEmpty ?? true);
    final loaded =
        !feed.isLoading &&
        !friends.isLoading &&
        !requests.isLoading &&
        !challenges.isLoading &&
        !blocked.isLoading;
    // Une erreur n'est PAS un écran vide : « personne ici » serait un
    // mensonge si le serveur a simplement refusé de répondre. La PREMIÈRE
    // erreur porte la cause — hors ligne ou panne, l'état affiché le dit.
    final error =
        feed.error ??
        friends.error ??
        requests.error ??
        challenges.error ??
        blocked.error;
    // PREMIER chargement seulement : pendant un rafraîchissement, Riverpod
    // conserve la valeur précédente (`valueOrNull` reste peuplé) et l'écran
    // continue de la montrer — remplacer la liste par un indicateur ferait
    // sauter la position de lecture à chaque écriture.
    final hasData =
        feed.hasValue ||
        friends.hasValue ||
        requests.hasValue ||
        challenges.hasValue ||
        blocked.hasValue;

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
                  style: AppTypography.display.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
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
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapRow),
          if (error != null)
            ConnectionAwareError(
              error: error,
              title: 'Communauté indisponible',
              message: 'Impossible de charger le fil pour le moment.',
              offlineMessage:
                  'Les amis, les encouragements et les défis '
                  'vivent sur le serveur. Reviens quand le réseau est là.',
              onRetry: () {
                ref
                  ..invalidate(encouragementsProvider)
                  ..invalidate(communityFriendsProvider)
                  ..invalidate(friendRequestsProvider)
                  ..invalidate(communityChallengesProvider)
                  ..invalidate(blockedUsersProvider);
              },
            )
          else if (!hasData)
            const AppLoadingIndicator()
          else if (loaded && isEmpty)
            AppEmptyState(
              icon: Icons.group_outlined,
              title: 'Personne ici pour l’instant',
              message:
                  'Ajoute un premier ami par son adresse e-mail : vous '
                  'verrez vos séries, et vous pourrez vous encourager.',
              actionLabel: 'Ajouter un ami',
              onAction: () => _addFriend(context, actions),
            )
          else
            CommunitySections(
              requests: requests.valueOrNull,
              feed: feed.valueOrNull,
              friends: friends.valueOrNull,
              challenges: challenges.valueOrNull,
              blocked: blocked.valueOrNull,
              sharesProgress: sharesProgress.valueOrNull,
            ),
        ],
      ),
    );
  }
}
