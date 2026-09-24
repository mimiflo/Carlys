import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/community_controllers.dart';
import '../providers/community_screen_state.dart';
import '../providers/community_tab_state.dart';
import '../widgets/community_challenges_tab.dart';
import '../widgets/community_flows.dart';
import '../widgets/community_friends_tab.dart';
import '../widgets/community_league_tab.dart';
import '../widgets/community_search_bar.dart';

/// Communauté — les autres, comme moteur. Ensemble, plus loin.
///
/// La page empilait tout sur un seul défilement : demandes, fil, amis,
/// défis, ligue, confidentialité. La refonte de septembre 2026 la range en
/// TROIS onglets — Défis, Ligue, Amis — sans rien retirer. Chaque onglet
/// tranche lui-même entre erreur, chargement et contenu, sur SES sources :
/// une ligue en panne ne masque plus les défis.
///
/// L'en-tête porte deux gestes : la loupe, qui filtre l'onglet ouvert (la
/// Communauté n'énumère personne), et l'ajout d'un ami.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({this.initialTab, super.key});

  /// L'onglet à ouvrir, quand la route le demande (`?onglet=amis`) : un
  /// raccourci de l'accueil ouvre l'onglet qui répond à ce qu'il annonce.
  final CommunityTab? initialTab;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    _open(widget.initialTab);
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _open(widget.initialTab);
    }
  }

  /// Hors du build : un provider ne s'écrit pas pendant qu'on le lit.
  void _open(CommunityTab? tab) {
    if (tab == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(communityTabProvider.notifier).state = tab;
        // Un raccourci ouvre l'onglet qu'il annonce SANS filtre resté
        // d'avant : un titre de défi tapé dans la loupe masquerait l'ami
        // dont l'accueil vient d'annoncer le mot.
        ref.read(communitySearchProvider.notifier).state = null;
      }
    });
  }

  /// L'onglet choisi à la main. L'adresse le SUIT : sans quoi, arrivée par
  /// `?onglet=amis` puis passée aux Défis, un nouveau raccourci vers les
  /// Amis visait l'adresse déjà en place — rien ne changeait, et le
  /// raccourci ouvrait l'onglet qu'il n'annonçait pas.
  void _select(CommunityTab tab) {
    ref.read(communityTabProvider.notifier).state = tab;
    context.go(AppRoutes.communityTab(tab));
  }

  void _toggleSearch() {
    final search = ref.read(communitySearchProvider.notifier);
    search.state = search.state == null ? '' : null;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(communityTabProvider);
    final searching = ref.watch(communitySearchProvider) != null;
    // Le compte des demandes en attente se lit sur la piste, sans ouvrir
    // l'onglet Amis — et l'écouter ici le garde vivant.
    final pending = ref.watch(friendRequestsProvider).valueOrNull?.length ?? 0;
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return AppDarkScaffold(
      // TIRER POUR RAFRAÎCHIR — indispensable ici, pas confortable.
      // Demandes d'ami, encouragements, défis et classement arrivent des
      // AUTRES : rien sur l'appareil ne déclenche leur relecture. Et l'onglet
      // vit dans un `IndexedStack`, donc il reste monté pour toute la durée
      // de l'application : `autoDispose` ne se déclenche jamais.
      body: RefreshIndicator(
        onRefresh: () => reloadCommunity(ref),
        color: AppColors.primaryLight,
        backgroundColor: AppColors.darkSurface,
        child: ListView(
          // L'anneau doit pouvoir se saisir même quand la liste tient dans
          // l'écran — sinon le geste ne part pas sur un compte tout neuf.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            MediaQuery.paddingOf(context).top + AppSpacing.md,
            AppSpacing.md,
            bottomInset + AppSpacing.gapSection,
          ),
          children: [
            AppScreenHeader(
              title: 'Communauté',
              tagline: 'Ensemble, plus loin',
              showBack: false,
              actions: [
                AppRoundIconButton(
                  icon: AppIcons.search,
                  tooltip: searching ? 'Fermer la recherche' : 'Rechercher',
                  isActive: searching,
                  onPressed: _toggleSearch,
                ),
                AppRoundIconButton(
                  icon: AppIcons.inviteFriends,
                  color: AppColors.accent,
                  tooltip: 'Ajouter un ami',
                  onPressed: () => addFriendFlow(
                    context,
                    ref.read(communityActionsProvider),
                  ),
                ),
              ],
            ),
            if (searching) ...[
              const SizedBox(height: AppSpacing.md),
              CommunitySearchBar(tab: tab),
            ],
            const SizedBox(height: AppSpacing.md),
            AppSegmentedTabs(
              segments: [
                for (final entry in CommunityTab.values)
                  AppSegment(
                    entry.label,
                    count: entry == CommunityTab.amis ? pending : 0,
                  ),
              ],
              selectedIndex: tab.index,
              onSelected: (index) => _select(CommunityTab.values[index]),
            ),
            const SizedBox(height: AppSpacing.lg),
            switch (tab) {
              CommunityTab.defis => const CommunityChallengesTab(),
              CommunityTab.ligue => const CommunityLeagueTab(),
              CommunityTab.amis => const CommunityFriendsTab(),
            },
          ],
        ),
      ),
    );
  }
}
