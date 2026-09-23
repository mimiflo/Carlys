import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/illustrated_banner.dart';
import '../../domain/entities/league.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import '../providers/community_tab_state.dart';
import 'community_gestures.dart';
import 'community_section.dart';
import 'league/league_invitation_card.dart';
import 'league/league_ranking_card.dart';
import 'league/league_status_card.dart';
import 'league/league_wording.dart';

/// L'onglet LIGUE : où j'en suis, le classement de la semaine, et un mot
/// pour la suite — d'après la maquette du 23 septembre 2026.
///
/// Deux visages, et c'est le « périmètre CHOISI » du principe 5 : sans
/// adhésion, l'invitation et le barème, jamais des noms d'inconnus ; une fois
/// entrée, ma division, mon écart avec la zone de montée, et le classement
/// avec MA ligne même hors du podium.
class CommunityLeagueTab extends ConsumerWidget {
  const CommunityLeagueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(leagueProvider);
    final query = ref.watch(communitySearchProvider) ?? '';

    return CommunityTabGate(
      sources: [league],
      errorTitle: 'Ligue indisponible',
      offlineMessage:
          'La ligue vit sur le serveur : ton classement revient avec le '
          'réseau.',
      builder: (context) {
        final gestures = CommunityGestures(
          ref.read(communityActionsProvider),
          ref.read(communityModerationActionsProvider),
        );
        final chargee = league.requireValue;
        if (!chargee.joined) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LeagueInvitationCard(
                division: chargee.division,
                onJoin: () => gestures.setLeagueJoined(context, joined: true),
              ),
              const SizedBox(height: AppSpacing.gapRow),
              // Le même mot qu'une fois entrée, au futur : rien n'est
              // compté avant l'adhésion, et la bannière ne le cache pas.
              const IllustratedBanner(
                title: 'Petits efforts,',
                titleAccent: 'grands résultats.',
                body: 'Dès que tu rejoins la ligue, chaque séance compte.',
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LeagueStatusCard(league: chargee),
            const SizedBox(height: AppSpacing.gapRow),
            LeagueRankingCard(league: chargee, query: query),
            const SizedBox(height: AppSpacing.gapRow),
            IllustratedBanner(
              title: 'Petits efforts,',
              titleAccent: 'grands résultats.',
              body: _cheer(chargee),
            ),
            const SizedBox(height: AppSpacing.gapSection),
            // Sortir ne se confirme pas : rien ne se perd, la semaine en
            // cours se règle normalement. Mais le geste reste discret, en
            // pied d'onglet, loin de ce qu'on vient regarder.
            Center(
              child: TextButton(
                onPressed: () =>
                    gestures.setLeagueJoined(context, joined: false),
                child: Text(
                  'Quitter la ligue',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Le mot de la bannière : « la prochaine ligue » n'existe pas en Diamant.
  static String _cheer(League league) => nextDivisionOf(league.division) == null
      ? 'Chaque séance t’aide à tenir ta place au sommet.'
      : 'Chaque séance te rapproche de la prochaine ligue.';
}
