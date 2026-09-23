import 'package:flutter/material.dart';

import '../../../../../core/utilities/text_search.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';
import 'league_ranking_sheet.dart';
import 'league_standing_row.dart';
import 'league_wording.dart';

/// LE CLASSEMENT DE LA SEMAINE : le podium, MA ligne même hors du podium,
/// et la porte vers le classement complet.
///
/// Le serveur rend la division ENTIÈRE ; la carte n'en montre qu'un extrait,
/// et la feuille « Voir le classement complet » montre le reste, sans
/// nouvelle requête. Pendant une recherche, la carte montre toutes les
/// lignes dont le prénom correspond, podium ou pas.
class LeagueRankingCard extends StatelessWidget {
  const LeagueRankingCard({required this.league, this.query = '', super.key});

  final League league;

  /// La recherche de la loupe ; vide, la carte montre le podium.
  final String query;

  /// Les places du podium.
  static const int podium = 3;

  static const double _iconSize = 22;

  /// Les lignes à montrer : le podium et moi, ou les résultats d'une
  /// recherche.
  List<LeagueStanding> get visibleRows {
    if (query.trim().isNotEmpty) {
      return [
        for (final row in league.standings)
          if (matchesSearch(row.isMe ? 'Toi' : row.displayName, query)) row,
      ];
    }
    final top = league.standings.take(podium).toList();
    final me = league.me;
    return [
      ...top,
      // Ma ligne, même hors du podium.
      if (me != null && me.rank > podium && !top.contains(me)) me,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = visibleRows;
    final searching = query.trim().isNotEmpty;

    // Une carte, un nœud : sans frontière, tout l'onglet se fondait en une
    // seule annonce — et le geste d'un bouton s'étendait à la page.
    return Semantics(
      container: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  AppIcons.community,
                  size: _iconSize,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      'Classement de la semaine',
                      style: AppTypography.heading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  label: league.daysLeft <= 0
                      ? 'Dernier jour de la semaine'
                      : 'Encore ${league.daysLeft} jours avant la fin de la '
                            'semaine',
                  excludeSemantics: true,
                  child: AppPill(
                    label: leagueCountdown(league),
                    tone: AppPillTone.primary,
                    mono: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (league.standings.isEmpty)
              Text(
                'Personne n’a encore marqué. Une séance suffit à ouvrir le bal.',
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              )
            else ...[
              const LeagueTableHeader(),
              const Divider(height: 1, color: AppColors.rowDivider),
              const SizedBox(height: AppSpacing.xxs),
              if (searching && rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'Personne ne s’appelle ainsi dans ta ligue.',
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ),
              for (final row in rows) ...[
                LeagueStandingRow(standing: row),
                const SizedBox(height: AppSpacing.xxs),
              ],
              const SizedBox(height: AppSpacing.xs),
              _FullRankingButton(
                onTap: () => showLeagueRankingSheet(context, league),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FullRankingButton extends StatelessWidget {
  const _FullRankingButton({required this.onTap});

  final VoidCallback onTap;

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: AppColors.darkBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: AppColors.darkBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.ranking,
                    size: _iconSize,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Voir le classement complet',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    size: _iconSize,
                    color: AppColors.primaryLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
