import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../domain/entities/community.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import '../widgets/add_friend_sheet.dart';
import '../widgets/community_feedback.dart';
import '../widgets/community_sections.dart';
import '../widgets/friends_empty_card.dart';
import '../widgets/new_friend_challenge_sheet.dart';

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

  /// Lance un défi à ses amis. La liste d'amis vient de l'écran, déjà
  /// chargée : la feuille n'a pas à la redemander, et une feuille qui
  /// attendrait le réseau pour s'ouvrir se lirait comme une lenteur.
  Future<void> _newFriendChallenge(
    BuildContext context,
    CommunityActions actions,
    List<CommunityFriend> friends,
  ) async {
    final draft = await showNewFriendChallengeSheet(context, friends: friends);
    if (draft == null || !context.mounted) {
      return;
    }
    await runCommunityGesture(context, () async {
      await actions.createFriendChallenge(draft);
      return 'Ton défi est lancé. Tes amis vont le recevoir.';
    });
  }

  /// Redemande TOUT au serveur, et attend la réponse.
  ///
  /// L'attente n'est pas décorative : `RefreshIndicator` garde son anneau
  /// tant que ce futur n'est pas terminé, et le geste doit durer aussi
  /// longtemps que l'appel.
  static Future<void> _reload(WidgetRef ref) async {
    ref
      ..invalidate(encouragementsProvider)
      ..invalidate(communityFriendsProvider)
      ..invalidate(friendRequestsProvider)
      ..invalidate(communityChallengesProvider)
      ..invalidate(friendChallengesProvider)
      ..invalidate(blockedUsersProvider);
    await Future.wait([
      ref.read(encouragementsProvider.future),
      ref.read(communityFriendsProvider.future),
      ref.read(friendRequestsProvider.future),
      ref.read(communityChallengesProvider.future),
      ref.read(friendChallengesProvider.future),
      ref.read(blockedUsersProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(encouragementsProvider);
    final friends = ref.watch(communityFriendsProvider);
    final requests = ref.watch(friendRequestsProvider);
    final challenges = ref.watch(communityChallengesProvider);
    final friendChallenges = ref.watch(friendChallengesProvider);
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
      // TIRER POUR RAFRAÎCHIR — indispensable ici, pas confortable.
      // Demandes d'ami, encouragements et défis arrivent des AUTRES : rien
      // sur l'appareil ne déclenche leur relecture. Et l'onglet vit dans un
      // `IndexedStack`, donc il reste monté pour toute la durée de
      // l'application : `autoDispose` ne se déclenche jamais et les listes
      // gelaient au premier chargement. Une demande reçue n'apparaissait
      // qu'après avoir tué l'application.
      body: RefreshIndicator(
        onRefresh: () => _reload(ref),
        color: AppColors.primaryLight,
        backgroundColor: AppColors.darkSurface,
        child: ListView(
          // L'anneau doit pouvoir se saisir même quand la liste tient dans
          // l'écran — sinon le geste ne part pas sur un compte tout neuf.
          physics: const AlwaysScrollableScrollPhysics(),
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
                    style: AppTypography.pageTitle.copyWith(
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
                onRetry: () => unawaited(_reload(ref)),
              )
            else if (!hasData)
              const AppLoadingIndicator()
            else if (loaded && isEmpty)
              // Le serveur crée les défis du mois à la lecture : en ligne, cet
              // état ne se voit que si le serveur n'a VRAIMENT rien rendu. Hors
              // ligne, c'est l'état d'erreur ci-dessus qui parle, jamais
              // « personne ici ». Le premier ami, lui, s'invite dans la section
              // « Amis » des sections (voir FriendsEmptyCard).
              AppEmptyState(
                icon: Icons.group_outlined,
                title: 'Personne ici pour l’instant',
                message: FriendsEmptyCard.invitation,
                actionLabel: 'Ajouter un ami',
                onAction: () => _addFriend(context, actions),
              )
            else
              CommunitySections(
                requests: requests.valueOrNull,
                feed: feed.valueOrNull,
                friends: friends.valueOrNull,
                challenges: challenges.valueOrNull,
                friendChallenges: friendChallenges.valueOrNull,
                blocked: blocked.valueOrNull,
                sharesProgress: sharesProgress.valueOrNull,
                onAddFriend: () => _addFriend(context, actions),
                onNewFriendChallenge: () => _newFriendChallenge(
                  context,
                  actions,
                  friends.valueOrNull ?? const [],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
