import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/academy_progress.dart';
import '../../domain/entities/academy.dart';

/// Le titre d'un domaine, et où en est sa lecture.
///
/// C'est ici que le COMPTE se lit, pas sur la pastille : « 3 / 4 » sous un
/// titre se comprend d'un coup d'œil, alors que douze pastilles allongées
/// d'un compte transforment la barre en couloir.
///
/// Le compte, la jauge, et depuis l'arbitrage produit de septembre 2026
/// (consigné dans `docs/product/academy.md`) un pourcentage : une POSITION
/// dans le contenu du domaine, qui nomme sa base — le lecteur d'écran dit
/// « du domaine ». C'est cette base nommée qui le distingue de l'axe
/// « Maîtrise » du profil, compté sur une cible fixe : deux nombres qui
/// disent sur quoi ils portent ne se contredisent pas.
class AcademyDomainHeader extends StatelessWidget {
  const AcademyDomainHeader({
    required this.category,
    required this.progress,
    this.onQuiz,
    super.key,
  });

  final AcademyCategory category;

  /// `null` tant que l'avancement n'est pas connu : le titre s'affiche seul
  /// plutôt qu'avec un « 0 / 4 » qui se lirait comme « tu n'as rien lu ».
  final DomainProgress? progress;

  /// Ouvre le quiz du domaine. L'affordance ne paraît que sur un domaine
  /// BOUCLÉ : le quiz est une répétition pour ancrer, pas un examen
  /// d'entrée — avant la fin, il poserait des questions jamais lues.
  final VoidCallback? onQuiz;

  @override
  Widget build(BuildContext context) {
    final avancement = progress;

    return Semantics(
      label: avancement == null
          ? category.label
          : '${category.label}, ${avancement.abordees} leçons abordées '
                'sur ${avancement.total}, ${avancement.pourcent} pour cent '
                'du domaine'
                '${avancement.termine ? ', domaine bouclé' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppSectionLabel(category.label),
              if (avancement != null && avancement.termine) ...[
                const SizedBox(width: AppSpacing.xxs),
                const Icon(AppIcons.record, size: 14, color: AppColors.accent),
              ],
              const Spacer(),
              if (avancement != null)
                Text(
                  '${avancement.abordees} / ${avancement.total}'
                  ' · ${avancement.pourcent} %',
                  style: AppTypography.resized(AppTypography.labelMono, 11)
                      .copyWith(
                        color: avancement.termine
                            ? AppColors.accent
                            : AppColors.darkTextTertiary,
                      ),
                ),
            ],
          ),
          if (avancement != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            AppGauge(
              progress: avancement.ratio,
              color: avancement.termine
                  ? AppColors.accent
                  : AppColors.primaryLight,
              height: 3,
            ),
          ],
          if (avancement != null && avancement.termine && onQuiz != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              button: true,
              label:
                  'Quiz ${category.label} : rejouer les questions du '
                  'domaine',
              excludeSemantics: true,
              child: InkWell(
                onTap: onQuiz,
                borderRadius: AppRadius.cardSecondaryAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      AppIcons.question,
                      size: 14,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Quiz du domaine',
                      style: AppTypography.label.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const Icon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: AppColors.primaryLight,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
