import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';
import 'league_division_header.dart';
import 'league_last_result.dart';
import 'league_rule_tiles.dart';
import 'league_wording.dart';

/// OÙ J'EN SUIS dans ma ligue cette semaine : la division et celle qui
/// vient, l'écart avec la zone de montée, et ce qui rapporte des points.
///
/// La jauge ne mesure QUE ce que le serveur calcule (`League.promotion`) et
/// dit toujours sur quoi elle porte : la montée se joue au rang, et une
/// jauge vers un seuil de points inventé promettrait une montée qui n'aurait
/// pas forcément lieu. Voir `league_wording.dart`.
class LeagueStatusCard extends StatelessWidget {
  const LeagueStatusCard({required this.league, super.key});

  final League league;

  static const double _gaugeHeight = 8;

  @override
  Widget build(BuildContext context) {
    final progress = leagueProgressOf(league);
    final gauge = progress.gauge;

    // Une carte, un nœud : sans frontière, tout l'onglet se fondait en une
    // seule annonce — et le geste d'un bouton s'étendait à la page.
    return Semantics(
      container: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (league.lastResult != null) ...[
              LeagueLastResult(result: league.lastResult!),
              const SizedBox(height: AppSpacing.sm),
            ],
            LeagueDivisionHeader(
              division: league.division,
              status: progress.status,
            ),
            if (gauge != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                container: true,
                label: progress.gaugeSpoken,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppGauge(
                            progress: gauge,
                            color: AppColors.primary,
                            gradient: AppColors.violetRamp,
                            height: _gaugeHeight,
                          ),
                        ),
                        if (progress.gaugeLabel != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            progress.gaugeLabel!,
                            style: AppTypography.label.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (progress.caption != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        progress.caption!,
                        style: AppTypography.label.copyWith(
                          color: AppColors.darkTextTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const LeagueRuleTiles(),
          ],
        ),
      ),
    );
  }
}
