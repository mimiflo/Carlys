import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/league.dart';

/// L'ÉCHELLE des divisions : cinq barreaux, ceux atteints allumés.
///
/// Un barreau plutôt qu'une médaille par division : cinq couleurs de métal
/// seraient cinq valeurs visuelles en dur, et l'application se peint en
/// violet. Surtout, l'échelle DIT quelque chose que le nom seul ne dit pas —
/// où l'on est, et ce qu'il reste au-dessus.
class LeagueLadderBar extends StatelessWidget {
  const LeagueLadderBar({required this.division, super.key});

  final LeagueDivision division;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Division ${division.label}, '
          '${division.rung + 1} sur ${LeagueDivision.values.length}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final palier in LeagueDivision.values) ...[
            Expanded(
              child: Container(
                height: AppSpacing.xxs,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  color: palier.rung <= division.rung
                      ? null
                      : AppColors.darkBorderStrong,
                  gradient: palier.rung <= division.rung
                      ? AppColors.violetRamp
                      : null,
                ),
              ),
            ),
            if (palier != LeagueDivision.values.last)
              const SizedBox(width: AppSpacing.xxs),
          ],
        ],
      ),
    );
  }
}
