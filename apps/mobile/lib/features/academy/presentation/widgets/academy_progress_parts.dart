/// Les deux pièces de la carte « Ma progression » : la ligne du niveau et
/// une médaille de récompense. Extraites de la carte, qui touchait son plafond de
/// widget une fois ses rangées rendues souples en texte agrandi.
library;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progression/domain/reward.dart';
import '../../domain/academy_level.dart';

/// Le niveau atteint, et ce qui ouvre le suivant.
///
/// Le rang et le nom disent où on en est ; la droite dit le PROCHAIN pas,
/// jamais ce qui manque en creux : « encore 3 leçons avant Profondeur » est
/// une direction, « il te manque 3 leçons » serait un reproche.
class AcademyLevelLine extends StatelessWidget {
  const AcademyLevelLine({
    required this.niveau,
    required this.abordees,
    super.key,
  });

  final AcademyLevel niveau;
  final int abordees;

  @override
  Widget build(BuildContext context) {
    final prochain = nextAcademyLevelOf(abordees);

    return Semantics(
      label:
          'Niveau ${niveau.rang}, ${niveau.nom}'
          '${prochain == null ? '' : '. ${_versLeProchain(prochain)}'}',
      excludeSemantics: true,
      // Le prochain pas à droite quand il tient, dessous sinon : après un
      // `Spacer`, non flexible, il sortait de la carte dès 390 points.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Niveau ${niveau.rang}',
                style: AppTypography.resized(
                  AppTypography.labelMono,
                  11,
                ).copyWith(color: AppColors.primaryLight),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: AppWholeWordsText(
                  niveau.nom,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (prochain != null)
            Text(
              _versLeProchain(prochain),
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
        ],
      ),
    );
  }

  String _versLeProchain(AcademyLevel prochain) {
    final manque = prochain.seuil - abordees;
    final lecons = manque > 1 ? '$manque leçons' : '1 leçon';
    return 'encore $lecons avant ${prochain.nom}';
  }
}

/// Une médaille de récompense, gagnée ou sous cadenas.
class AcademyRewardSeal extends StatelessWidget {
  const AcademyRewardSeal({
    required this.reward,
    required this.metal,
    super.key,
  });

  /// `null` tant que la récompense n'est pas obtenue.
  final Reward? reward;

  /// Le métal qu'elle prend une fois gagnée.
  final AppMedalMetal metal;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    final gagne = reward;
    return Semantics(
      label: gagne == null ? 'Récompense à venir' : '${gagne.label}, obtenu',
      child: AppMedal(metal: gagne == null ? null : metal, size: size),
    );
  }
}
