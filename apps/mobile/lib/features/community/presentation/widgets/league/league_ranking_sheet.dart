import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';
import 'league_standing_row.dart';
import 'league_wording.dart';

/// Le classement COMPLET de la division, dans une feuille.
///
/// Rien de plus à charger : le serveur rend déjà tout MON GROUPE, vingt
/// joueurs au plus depuis septembre 2026 (une semaine ouverte avant les
/// groupes se finit telle quelle, division entière). La liste reste
/// paresseuse (`ListView.builder`) : ce plafond est une règle du serveur,
/// que l'écran n'a pas à supposer.
Future<void> showLeagueRankingSheet(BuildContext context, League league) {
  return showAppSheet<void>(
    context,
    builder: (_) => _LeagueRankingSheet(league: league),
  );
}

class _LeagueRankingSheet extends StatelessWidget {
  const _LeagueRankingSheet({required this.league});

  final League league;

  /// Part de l'écran que la feuille peut prendre, au plus : le haut de la
  /// page reste visible, et rappelle d'où l'on vient.
  static const double _maxHeightFactor = 0.8;

  @override
  Widget build(BuildContext context) {
    final rows = league.standings;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFactor,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      'Ligue ${league.division.label}',
                      style: AppTypography.title.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
                AppPill(
                  label: leagueCountdown(league),
                  tone: AppPillTone.primary,
                  mono: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${rows.length} ${rows.length <= 1 ? 'membre' : 'membres'} '
              'cette semaine',
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const LeagueTableHeader(),
            const Divider(height: 1, color: AppColors.rowDivider),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                itemCount: rows.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: LeagueStandingRow(standing: rows[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
