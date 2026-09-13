import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/recipe_selection.dart';
import '../controllers/recipes_controllers.dart';
import '../widgets/recipe_card.dart';

/// Recettes — deux volets : ce qu'on mange le matin ou entre les repas, et
/// les repas eux-mêmes.
///
/// Le premier volet se partage en sucré et salé, parce que c'est la première
/// question qu'on se pose devant un petit-déjeuner. Le second ne le fait pas :
/// trancher la saveur d'un déjeuner n'aide personne à choisir un plat.
///
/// L'ADAPTATION AU PROFIL ne cache rien. Les recettes qui servent l'objectif
/// de la personne passent devant et portent une pastille ; les autres
/// suivent. Filtrer viderait des volets entiers et déciderait à sa place.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  RecipeMoment _moment = RecipeMoment.petitDejCollation;
  RecipeSaveur _saveur = RecipeSaveur.sucre;

  /// La recette dépliée, au plus une : deux listes d'étapes ouvertes côte à
  /// côte ne se lisent pas.
  String? _ouverte;

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(recipesPackProvider);
    final goal = ref.watch(nutritionGoalProvider);
    final targetKcal = ref.watch(targetKcalProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('Recettes')),
      body: pack.when(
        loading: () => const AppLoadingIndicator(),
        error: (error, _) => const AppErrorState(
          title: 'Recettes indisponibles',
          message: 'Le livre de recettes n’a pas pu être chargé.',
        ),
        data: (recipes) {
          final visibles = recipesFor(
            recipes,
            moment: _moment,
            saveur: _moment == RecipeMoment.petitDejCollation ? _saveur : null,
            goal: goal,
          );

          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.gapRow,
              AppSpacing.gutter,
              MediaQuery.paddingOf(context).bottom + AppSpacing.gapSection,
            ),
            children: [
              _MomentBar(
                selected: _moment,
                onSelect: (moment) => setState(() {
                  _moment = moment;
                  _ouverte = null;
                }),
              ),
              if (_moment == RecipeMoment.petitDejCollation) ...[
                const SizedBox(height: AppSpacing.xs),
                _SaveurBar(
                  selected: _saveur,
                  onSelect: (saveur) => setState(() {
                    _saveur = saveur;
                    _ouverte = null;
                  }),
                ),
              ],
              const SizedBox(height: AppSpacing.gapRow),
              if (goal != null) ...[
                Text(
                  'Classées pour ton objectif : ${goal.label.toLowerCase()}.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapRow),
              ],
              if (visibles.isEmpty)
                const AppEmptyState(
                  title: 'Rien ici pour l’instant',
                  message: 'Ce volet n’a pas encore de recette.',
                )
              else
                for (final recipe in visibles) ...[
                  RecipeCard(
                    recipe: recipe,
                    expanded: _ouverte == recipe.id,
                    onToggle: () => setState(
                      () => _ouverte = _ouverte == recipe.id ? null : recipe.id,
                    ),
                    sharePercent: recipe.shareOfTargetPercent(targetKcal),
                    forGoal: recipe.suits(goal),
                  ),
                  const SizedBox(height: AppSpacing.gapRow),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Les deux volets.
class _MomentBar extends StatelessWidget {
  const _MomentBar({required this.selected, required this.onSelect});

  final RecipeMoment selected;
  final ValueChanged<RecipeMoment> onSelect;

  @override
  Widget build(BuildContext context) {
    // `Wrap` et non `Row` : « Petit-déj & collation » et « Déjeuner & dîner »
    // côte à côte débordent d'un téléphone étroit. Elles passent alors à la
    // ligne au lieu de se faire rogner.
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final moment in RecipeMoment.values)
          AppPill(
            label: moment.label,
            selected: selected == moment,
            selectedTone: AppPillTone.primary,
            onTap: () => onSelect(moment),
          ),
      ],
    );
  }
}

/// Sucré ou salé, dans le premier volet seulement.
class _SaveurBar extends StatelessWidget {
  const _SaveurBar({required this.selected, required this.onSelect});

  final RecipeSaveur selected;
  final ValueChanged<RecipeSaveur> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final saveur in RecipeSaveur.values)
          AppPill(
            label: saveur.label,
            selected: selected == saveur,
            selectedTone: AppPillTone.primary,
            onTap: () => onSelect(saveur),
          ),
      ],
    );
  }
}
