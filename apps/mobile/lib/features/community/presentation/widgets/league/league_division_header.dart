import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';
import 'league_shield.dart';
import 'league_wording.dart';

/// Le haut de la carte de ligue : « LIGUE », la division et celle qui vient,
/// une phrase, et le blason à droite.
///
/// Partagé par la carte d'une ligue rejointe et par l'invitation : la
/// division où l'on JOUE et celle où l'on ENTRERAIT se présentent pareil.
class LeagueDivisionHeader extends StatelessWidget {
  const LeagueDivisionHeader({
    required this.division,
    required this.status,
    this.showNext = true,
    super.key,
  });

  final LeagueDivision division;

  /// La phrase sous le titre.
  final String status;

  /// « Bronze → Argent » : la division visée. Faux dans l'invitation, où
  /// l'on ne vise encore rien.
  final bool showNext;

  static const double _trophySize = 18;
  static const double _arrowSize = 24;

  @override
  Widget build(BuildContext context) {
    final next = showNext ? nextDivisionOf(division) : null;
    final titleStyle = AppTypography.resized(
      AppTypography.display,
      26,
    ).copyWith(color: AppColors.darkTextPrimary);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // L'étiquette du titre commence déjà par « Ligue » : lue en
              // plus, elle doublerait le mot.
              ExcludeSemantics(
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.leagueTrophy,
                      size: _trophySize,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'LIGUE',
                      style: AppTypography.resized(
                        AppTypography.labelMono,
                        12,
                      ).copyWith(color: AppColors.primaryLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                // Son propre nœud : sans lui, le drapeau « en-tête » coifferait
                // la carte entière, barème compris.
                container: true,
                header: true,
                label: next == null
                    ? 'Ligue ${division.label}'
                    : 'Ligue ${division.label}, prochaine ligue ${next.label}',
                excludeSemantics: true,
                // « Platine → Diamant » ne tient pas en 26 points sur un
                // petit téléphone : le titre se réduit plutôt que de se
                // couper, et ne passe jamais à la ligne au milieu de la
                // flèche.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(division.label, style: titleStyle),
                      if (next != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          AppIcons.arrowForward,
                          size: _arrowSize,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(next.label, style: titleStyle),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Un nœud à elle, lu juste après le titre qu'elle commente.
              Semantics(
                container: true,
                child: Text(
                  status,
                  style: AppTypography.resized(
                    AppTypography.body,
                    14,
                  ).copyWith(color: AppColors.darkTextSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        LeagueShield(division: division),
      ],
    );
  }
}
