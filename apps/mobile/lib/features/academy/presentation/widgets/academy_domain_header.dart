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
/// Un compte et une jauge, jamais un pourcentage : la jauge est une position
/// dans un contenu, le pourcentage se lirait comme une note. La règle de
/// non-concurrence (`docs/product/progression.md`) l'exclut, parce que l'axe
/// « Maîtrise » du profil compte déjà ces mêmes leçons sur une autre base.
class AcademyDomainHeader extends StatelessWidget {
  const AcademyDomainHeader({
    required this.category,
    required this.progress,
    super.key,
  });

  final AcademyCategory category;

  /// `null` tant que l'avancement n'est pas connu : le titre s'affiche seul
  /// plutôt qu'avec un « 0 / 4 » qui se lirait comme « tu n'as rien lu ».
  final DomainProgress? progress;

  @override
  Widget build(BuildContext context) {
    final avancement = progress;

    return Semantics(
      label: avancement == null
          ? category.label
          : '${category.label}, ${avancement.abordees} leçons abordées '
                'sur ${avancement.total}'
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
                  '${avancement.abordees} / ${avancement.total}',
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
        ],
      ),
    );
  }
}
