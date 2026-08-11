import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/community_controllers.dart';
import '../widgets/challenge_card.dart';
import '../widgets/encouragement_tile.dart';
import '../widgets/friend_card.dart';

/// Communauté — les autres, comme moteur.
///
/// Trois étages : le fil des encouragements reçus, les amis (série visible
/// seulement si l'ami partage sa progression), les défis sportifs et
/// culturels avec leur progression COLLECTIVE.
///
/// Tant que le serveur communautaire n'existe pas, l'écran vit sur ses états
/// vides — en mode démonstration, le dépôt embarqué le fait vivre en entier.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(encouragementsProvider);
    final friends = ref.watch(communityFriendsProvider);
    final challenges = ref.watch(communityChallengesProvider);
    final actions = ref.read(communityActionsProvider);
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    final isEmpty = (feed.valueOrNull?.isEmpty ?? true) &&
        (friends.valueOrNull?.isEmpty ?? true) &&
        (challenges.valueOrNull?.isEmpty ?? true);
    final loaded =
        !feed.isLoading && !friends.isLoading && !challenges.isLoading;
    // Une erreur n'est PAS un écran vide : « bientôt du monde ici » serait un
    // mensonge si le serveur a simplement refusé de répondre.
    final hasError = feed.hasError || friends.hasError || challenges.hasError;
    // PREMIER chargement seulement : pendant un rafraîchissement, Riverpod
    // conserve la valeur précédente (`valueOrNull` reste peuplé) et l'écran
    // continue de la montrer — remplacer la liste par un indicateur ferait
    // sauter la position de lecture à chaque écriture.
    final hasData = feed.hasValue || friends.hasValue || challenges.hasValue;

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
          Text(
            'Communauté',
            style: AppTypography.display
                .copyWith(color: AppColors.darkTextPrimary),
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
                ref.invalidate(encouragementsProvider);
                ref.invalidate(communityFriendsProvider);
                ref.invalidate(communityChallengesProvider);
              },
            )
          else if (!hasData)
            const AppLoadingIndicator()
          else if (loaded && isEmpty)
            const AppEmptyState(
              icon: Icons.group_outlined,
              title: 'Bientôt du monde ici',
              message:
                  'Les amis, encouragements et défis arrivent avec le serveur '
                  'communautaire. En attendant, ta progression t’appartient.',
            )
          else ...[
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
                      onToggle: () => actions.toggleChallenge(challenge.id),
                    ),
                  )
                  .toList(),
            ),
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
