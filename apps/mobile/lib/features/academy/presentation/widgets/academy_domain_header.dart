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

  static const double _trophySize = 18;

  @override
  Widget build(BuildContext context) {
    final avancement = progress;

    // Le titre porte TOUT ce que l'en-tête dit (nom, compte, bouclé) ; le
    // lien du quiz reste un nœud à part, sans quoi il serait exclu avec le
    // reste et le lecteur d'écran ne pourrait plus l'actionner.
    final title = Semantics(
      header: true,
      label: avancement == null
          ? category.label
          : '${category.label}, ${avancement.abordees} leçons abordées '
                'sur ${avancement.total}, ${avancement.pourcent} pour cent '
                'du domaine'
                '${avancement.termine ? ', domaine bouclé' : ''}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: AppWholeWordsText(
              category.label,
              style: AppTypography.heading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          if (avancement != null && avancement.termine) ...[
            const SizedBox(width: AppSpacing.xxs),
            const Icon(
              AppIcons.record,
              size: _trophySize,
              color: AppColors.accent,
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Le titre à gauche ; à droite, le quiz d'un domaine bouclé, ou
        // le compteur — dessous quand ils ne tiennent pas côte à côte.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            title,
            if (avancement != null && avancement.termine && onQuiz != null)
              Semantics(
                button: true,
                label:
                    'Quiz ${category.label} : rejouer les questions du '
                    'domaine',
                onTap: onQuiz,
                excludeSemantics: true,
                child: AppLinkButton(
                  label: 'Quiz du domaine',
                  onPressed: onQuiz!,
                ),
              )
            else if (avancement != null)
              // Déjà dit par le titre : le compteur ne se relit pas.
              ExcludeSemantics(
                child: Text(
                  '${avancement.abordees} / ${avancement.total}'
                  ' · ${avancement.pourcent} %',
                  style: AppTypography.resized(
                    AppTypography.labelMono,
                    11,
                  ).copyWith(color: AppColors.darkTextTertiary),
                ),
              ),
          ],
        ),
        if (avancement != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          ExcludeSemantics(
            child: AppGauge(
              progress: avancement.ratio,
              color: avancement.termine
                  ? AppColors.accent
                  : AppColors.primaryLight,
              height: 3,
            ),
          ),
        ],
      ],
    );
  }
}
