import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/recipe.dart';

/// Une recette dans la liste : repliée elle sert à CHOISIR, dépliée à
/// CUISINER.
///
/// Repliée on lit le titre, ce qu'elle apporte, le temps et ce qu'elle pèse
/// dans la journée ; dépliée, les ingrédients puis les étapes. Le contenu
/// déplié est RETIRÉ de l'arbre, pas masqué : une liste de trente recettes
/// n'a pas à porter trente listes d'étapes construites pour rien.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    required this.recipe,
    required this.expanded,
    required this.onToggle,
    this.sharePercent,
    this.forGoal = false,
    super.key,
  });

  final Recipe recipe;
  final bool expanded;
  final VoidCallback onToggle;

  /// Part de la cible calorique du jour, si elle est connue.
  final int? sharePercent;

  /// La recette sert l'objectif de la personne.
  final bool forGoal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  recipe.title,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.darkTextTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            recipe.summary,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapTile),
          _Facts(recipe: recipe, sharePercent: sharePercent, forGoal: forGoal),
          if (expanded) ...[
            const SizedBox(height: AppSpacing.gapRow),
            _Block(
              label: 'Ingrédients',
              lines: recipe.ingredients,
              numbered: false,
            ),
            const SizedBox(height: AppSpacing.gapRow),
            _Block(label: 'Préparation', lines: recipe.steps, numbered: true),
          ],
        ],
      ),
    );
  }
}

/// La ligne de faits : temps, calories, macros, et ce que la recette pèse
/// dans la journée de la personne.
class _Facts extends StatelessWidget {
  const _Facts({
    required this.recipe,
    required this.sharePercent,
    required this.forGoal,
  });

  final Recipe recipe;
  final int? sharePercent;
  final bool forGoal;

  @override
  Widget build(BuildContext context) {
    final share = sharePercent;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        if (forGoal)
          const AppPill(label: 'Pour ton objectif', tone: AppPillTone.primary),
        AppPill(label: '${recipe.minutes} MIN', mono: true),
        AppPill(label: '${recipe.kcal} KCAL', mono: true),
        AppPill(label: '${recipe.proteinG} G PROT', mono: true),
        AppPill(label: '${recipe.carbsG} G GLUC', mono: true),
        AppPill(label: '${recipe.fatG} G LIP', mono: true),
        // La part de la journée n'apparaît QUE si la cible est connue :
        // sans profil complet, ce rapport n'existe pas.
        if (share != null)
          AppPill(
            label: '$share % DE TA JOURNÉE',
            mono: true,
            tone: AppPillTone.accent,
          ),
      ],
    );
  }
}

/// Ingrédients (à puces) ou préparation (numérotée, l'ordre y compte).
class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.lines,
    required this.numbered,
  });

  final String label;
  final List<String> lines;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(label),
        const SizedBox(height: AppSpacing.xs),
        for (final (index, line) in lines.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: numbered
                    ? Text(
                        '${index + 1}.',
                        style: AppTypography.labelMono.copyWith(
                          color: AppColors.primaryLight,
                        ),
                      )
                    : const Icon(
                        Icons.circle,
                        size: 6,
                        color: AppColors.primaryLight,
                      ),
              ),
              Expanded(
                child: Text(
                  line,
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
