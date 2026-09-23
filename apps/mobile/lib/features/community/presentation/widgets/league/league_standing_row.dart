import 'package:flutter/material.dart';

import '../../../../../core/utilities/formatting.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';
import 'league_crown.dart';
import 'league_metal.dart';

/// Une ligne du classement : le rang, la couronne du podium, l'initiale, le
/// prénom, les points.
///
/// MA ligne se détache — cadre violet, « Toi » —, pour se trouver d'un coup
/// d'œil : un classement où l'on ne se trouve pas ne motive personne.
class LeagueStandingRow extends StatelessWidget {
  const LeagueStandingRow({required this.standing, super.key});

  final LeagueStanding standing;

  /// La colonne du rang — partagée avec l'en-tête du tableau.
  static const double rankSize = 32;
  static const double _crownSlot = 24;
  static const double _avatarSize = 36;

  @override
  Widget build(BuildContext context) {
    final me = standing.isMe;
    final name = me ? 'Toi' : standing.displayName;
    final crown = LeagueMetal.ofPodiumRank(standing.rank);
    final points = '${formatThousands(standing.score)} pts';

    final row = Row(
      children: [
        Container(
          width: rankSize,
          height: rankSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: me ? null : AppColors.darkSurfaceAlt,
          ),
          child: Text(
            '${standing.rank}',
            style: AppTypography.subheading.copyWith(
              color: me ? AppColors.primaryLight : AppColors.darkTextPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: _crownSlot,
          child: crown == null ? null : LeagueCrown(metal: crown),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppInitialAvatar(
          name: me ? standing.displayName : name,
          size: _avatarSize,
          highlighted: me,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyLarge.copyWith(
              color: me
                  ? AppColors.darkTextPrimary
                  : AppColors.darkTextSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          points,
          style: AppTypography.subheading.copyWith(
            color: me ? AppColors.primaryLight : AppColors.darkTextPrimary,
          ),
        ),
      ],
    );

    // Un nœud par ligne : le lecteur d'écran descend le classement place
    // par place, au lieu d'une seule annonce de toute la carte.
    return Semantics(
      container: true,
      label: [
        '${standing.rank}e',
        name,
        '${formatThousands(standing.score)} points',
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: me
            ? const BoxDecoration(
                color: AppColors.primaryBadgeBg,
                borderRadius: AppRadius.mdAll,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.primaryBadgeBorder),
                ),
              )
            : null,
        child: row,
      ),
    );
  }
}

/// L'en-tête du tableau : « # · Utilisateur · Points ».
class LeagueTableHeader extends StatelessWidget {
  const LeagueTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.label.copyWith(
      color: AppColors.darkTextTertiary,
    );
    // Aligné sur les colonnes de `LeagueStandingRow` : le rang, puis la
    // couronne et l'initiale sous « Utilisateur ».
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox(
              width: LeagueStandingRow.rankSize,
              child: Center(child: Text('#', style: style)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Utilisateur', style: style)),
            Text('Points', style: style),
          ],
        ),
      ),
    );
  }
}
