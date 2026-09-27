/// Les deux pièces de la carte « Où tu en es » : la ligne du niveau et un
/// sceau de récompense. Extraites de la carte, qui touchait son plafond de
/// widget une fois ses rangées rendues souples en texte agrandi.
library;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progression/domain/reward.dart';
import '../../../progression/presentation/widgets/award_seal.dart';
import '../../../progression/presentation/widgets/seal_size.dart';
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

/// Un sceau de récompense, gagné ou en attente.
class AcademyRewardSeal extends StatelessWidget {
  const AcademyRewardSeal({required this.reward, super.key});

  /// `null` tant que la récompense n'est pas obtenue.
  final Reward? reward;

  @override
  Widget build(BuildContext context) {
    final gagne = reward;
    if (gagne == null) {
      return Semantics(
        label: 'Récompense à venir',
        child: Opacity(
          opacity: 0.25,
          child: SizedBox.square(
            dimension: SealSize.small,
            child: Icon(
              AppIcons.record,
              size: 22,
              color: AppColors.darkTextTertiary,
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: '${gagne.label}, obtenu',
      child: AwardSeal(
        kind: gagne.kind,
        figure: gagne.figure,
        size: SealSize.small,
      ),
    );
  }
}
