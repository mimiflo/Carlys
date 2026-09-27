import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progression/domain/progression.dart';
import '../../../progression/domain/reward_engine.dart';
import '../../domain/academy_level.dart';
import '../../domain/academy_progress.dart';
import 'academy_progress_parts.dart';

/// Où en est la lecture du pack, et ce qu'elle a déjà rapporté.
///
/// L'Academy ne montrait AUCUN chiffre d'avancement, et les trois
/// récompenses de maîtrise ne paraissaient que sur les écrans de
/// progression : on pouvait boucler le pack sans jamais le voir dit là où on
/// l'avait fait.
///
/// Le COMPTE d'abord, le pourcentage ensuite et jamais sans sa base : « 63 %
/// du pack » est une position dans un contenu, arbitrage consigné dans
/// `docs/product/academy.md`. Le niveau, lui, est un jalon d'affichage : il
/// ne crée AUCUNE récompense, le journal fête déjà ces franchissements
/// (voir `academy_level.dart`).
///
/// L'état des sceaux se calcule ICI, à partir des seuls faits de l'Academy,
/// et non depuis `earnedRewardsProvider`. Ce provider-là lit l'historique
/// des séances et le profil dérivé : le brancher rendrait l'Academy
/// dépendante de la base d'entraînement pour afficher SES badges, alors que
/// tout son contenu est embarqué et qu'elle doit tenir hors ligne. Les six
/// règles concernées ne lisent que des comptes de leçons et de domaines —
/// un test le vérifie plutôt que de le supposer.
class AcademyProgressCard extends StatelessWidget {
  const AcademyProgressCard({required this.progress, super.key});

  /// Les récompenses de l'Academy, dans l'ordre où elles s'obtiennent.
  static const List<String> rewardIds = [
    'maitrise-5',
    'maitrise-moitie',
    'domaines-1',
    'domaines-moitie',
    'maitrise-pack',
    'domaines-tous',
  ];

  final AcademyProgress progress;

  /// Les faits que l'Academy connaît d'elle-même.
  ///
  /// `reachedTitle` est requis par le type mais AUCUNE des six règles ne le
  /// lit : un test l'atteste en évaluant les mêmes règles au premier et au
  /// dernier titre.
  static RewardFacts factsOf(AcademyProgress progress) => RewardFacts(
    reachedTitle: CarlysTitle.apprenti,
    lessonsAnswered: progress.abordees,
    lessonsTotal: progress.total,
    academyDomainsCompleted: progress.domainesTermines.length,
    academyDomainsServed: progress.domainesServis,
  );

  @override
  Widget build(BuildContext context) {
    final niveau = academyLevelOf(progress.abordees);
    final facts = factsOf(progress);
    final gagnees = {
      for (final regle in rewardCatalog)
        if (rewardIds.contains(regle.reward.id) && regle.isEarned(facts))
          regle.reward.id: regle.reward,
    };
    final termines = progress.domainesTermines.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.padCard),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionLabel('Où tu en es'),
          const SizedBox(height: AppSpacing.sm),
          // Le pourcentage à droite du compte quand il tient, dessous
          // sinon : non flexible, il écrasait le compte en texte agrandi.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.xs,
            children: [
              AppWholeWordsText(
                '${progress.abordees} leçons sur ${progress.total}',
                style: AppTypography.title.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              // La base du pourcentage se dit TOUJOURS : « du pack » est ce
              // qui le distingue de l'axe « Maîtrise » du profil, compté sur
              // une autre base.
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  '${progress.pourcent} % du pack',
                  style: AppTypography.resized(AppTypography.labelMono, 11)
                      .copyWith(
                        color: progress.pourcent >= 100
                            ? AppColors.accent
                            : AppColors.darkTextTertiary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            termines == 0
                ? 'Aucun domaine bouclé pour l’instant.'
                : '$termines domaine${termines > 1 ? 's' : ''} bouclé'
                      '${termines > 1 ? 's' : ''} sur ${progress.domainesServis}.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppGauge(
            progress: progress.total == 0
                ? 0
                : progress.abordees / progress.total,
            color: AppColors.primaryLight,
          ),
          // Le niveau ne paraît qu'à partir de la première leçon : avant,
          // un « niveau zéro » se lirait comme une note d'échec d'office.
          if (niveau != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AcademyLevelLine(niveau: niveau, abordees: progress.abordees),
          ],
          const SizedBox(height: AppSpacing.md),
          // Les sceaux déjà gagnés en pleine couleur, les autres éteints :
          // ce qui reste à faire se voit, sans jamais ressembler à un échec.
          // Six sceaux à l'écart de la maquette ; sur 320 points, où six
          // fois 34 + 8 ne tiennent pas, ce sont les ÉCARTS qui se
          // resserrent, jamais les sceaux.
          Row(
            children: [
              for (final (index, id) in rewardIds.indexed) ...[
                if (index > 0)
                  const Flexible(child: SizedBox(width: AppSpacing.xs)),
                AcademyRewardSeal(reward: gagnees[id]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
