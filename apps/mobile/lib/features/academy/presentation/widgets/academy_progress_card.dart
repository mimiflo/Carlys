import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progression/domain/progression.dart';
import '../../../progression/domain/reward.dart';
import '../../../progression/domain/reward_engine.dart';
import '../../../progression/presentation/widgets/award_seal.dart';
import '../../../progression/presentation/widgets/seal_size.dart';
import '../../domain/academy_progress.dart';

/// Où en est la lecture du pack, et ce qu'elle a déjà rapporté.
///
/// L'Academy ne montrait AUCUN chiffre d'avancement, et les trois
/// récompenses de maîtrise ne paraissaient que sur les écrans de
/// progression : on pouvait boucler le pack sans jamais le voir dit là où on
/// l'avait fait.
///
/// Un COMPTE, jamais un pourcentage global : la règle de non-concurrence
/// l'impose, parce que l'axe « Maîtrise » du profil rapporte déjà les leçons
/// à une cible fixe de 20 et afficherait un autre nombre pour le même
/// travail. Voir `docs/product/progression.md`.
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
          Text(
            '${progress.abordees} leçons sur ${progress.total}',
            style: AppTypography.title.copyWith(
              color: AppColors.darkTextPrimary,
            ),
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
          const SizedBox(height: AppSpacing.md),
          // Les sceaux déjà gagnés en pleine couleur, les autres éteints :
          // ce qui reste à faire se voit, sans jamais ressembler à un échec.
          Row(
            children: [
              for (final id in rewardIds) ...[
                _Sceau(reward: gagnees[id]),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Un sceau de récompense, gagné ou en attente.
class _Sceau extends StatelessWidget {
  const _Sceau({required this.reward});

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
