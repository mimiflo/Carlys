import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';
import 'league_division_header.dart';
import 'league_rule_tiles.dart';

/// L'INVITATION à entrer dans la ligue : on n'y joue qu'en le demandant.
///
/// La ligue est un opt-in (`docs/product/community.md`, principe 5) : sans
/// adhésion, la carte montre la division où l'on ENTRERAIT et le barème,
/// jamais les noms d'inconnus d'un classement.
class LeagueInvitationCard extends StatelessWidget {
  const LeagueInvitationCard({
    required this.division,
    required this.onJoin,
    super.key,
  });

  final LeagueDivision division;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    // Une carte, un nœud : sans frontière, tout l'onglet se fondait en une
    // seule annonce — et le geste d'un bouton s'étendait à la page.
    return Semantics(
      container: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LeagueDivisionHeader(
              division: division,
              status: 'Une semaine, un classement, et tout repart à zéro.',
              showNext: false,
            ),
            const SizedBox(height: AppSpacing.sm),
            // L'ancienne carte promettait « vingt personnes » : aucune
            // division n'est plafonnée côté serveur. La phrase ne promet plus
            // de nombre.
            Text(
              'Tes séances, tes minutes d’effort et tes kilomètres deviennent '
              'des points. Rien n’est compté avant que tu rejoignes la ligue, '
              'et ton rang ne touche jamais à ton titre Carlys.',
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const LeagueRuleTiles(),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Rejoindre la ligue',
              isExpanded: true,
              onPressed: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}
