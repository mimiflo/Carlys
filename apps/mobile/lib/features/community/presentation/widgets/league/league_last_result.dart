import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';
import 'league_wording.dart';

/// Le résultat de la semaine passée, annoncé UNE fois : sans lui, la
/// division changerait sous les yeux sans explication.
class LeagueLastResult extends StatelessWidget {
  const LeagueLastResult({required this.result, super.key});

  final LeagueResult result;

  static const double _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    final (icone, phrase) = switch (result) {
      final r when r.isPromotion => (
        AppIcons.trendingUp,
        'À la ${leaguePlace(r.rank)} la semaine passée : te voilà en '
            '${r.to.label}.',
      ),
      final r when r.isRelegation => (
        AppIcons.trendingDown,
        'À la ${leaguePlace(r.rank)} la semaine passée : retour en '
            '${r.to.label}.',
      ),
      final r => (
        AppIcons.trendingFlat,
        'À la ${leaguePlace(r.rank)} la semaine passée : tu restes en '
            '${r.to.label}.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.primaryBadgeBg,
        borderRadius: AppRadius.mdAll,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.primaryBadgeBorder),
        ),
      ),
      child: Row(
        children: [
          Icon(icone, size: _iconSize, color: AppColors.primaryLight),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              phrase,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
