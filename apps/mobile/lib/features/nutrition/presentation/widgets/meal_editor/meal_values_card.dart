import 'package:flutter/material.dart';

import '../../../../../core/utilities/formatting.dart';
import '../../../../../design_system/design_system.dart';
import '../../../domain/services/meal_composition.dart';
import '../../utils/meal_editor_state.dart';
import '../../utils/meal_editor_validation.dart';
import 'bound_text.dart';

/// Ce que le repas-éditeur remonte à l'état quand une tuile se saisit.
typedef MealValueSetters = ({
  ValueChanged<String> kcal,
  ValueChanged<String> protein,
  ValueChanged<String> carbs,
  ValueChanged<String> fat,
});

/// La carte VALEURS NUTRITIONNELLES : calories, protéines, glucides,
/// lipides, en quatre tuiles.
///
/// Repas COMPOSÉ : les tuiles se LISENT — l'aperçu des totaux que le
/// serveur calculera, « — » pour une macro qu'un aliment ignore. Repas
/// SAISI : chaque tuile porte sa case. Seules les calories sont
/// obligatoires ; une macro vide veut dire « on ne sait pas », jamais zéro.
class MealValuesCard extends StatelessWidget {
  const MealValuesCard({
    required this.state,
    required this.errors,
    required this.setters,
    super.key,
  });

  final MealEditorState state;

  /// Les fautes à montrer (déjà filtrées : aucune avant le premier envoi).
  final MealEditorErrors errors;
  final MealValueSetters setters;

  /// Quatre tuiles sur la rangée d'un téléphone, deux sur 320 points.
  static const double _tileWidth = 72;

  @override
  Widget build(BuildContext context) {
    final computed = state.isComposed;
    final faults = computed ? const <String>[] : errors.values;
    return AppTitledCard(
      icon: AppIcons.mealValues,
      title: 'Valeurs nutritionnelles',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppAdaptiveGrid(
            minItemWidth: _tileWidth,
            children: computed
                ? _readTiles(state.totals)
                : _entryTiles(state, errors, setters),
          ),
          if (faults.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            // Chaque case fautive annonce DÉJÀ sa faute au lecteur d'écran :
            // la phrase commune n'est là que pour les yeux.
            ExcludeSemantics(
              child: Text(
                faults.join(' '),
                style: AppTypography.body.copyWith(color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            computed
                ? 'Calculé à partir des aliments.'
                : 'Seules les calories sont obligatoires. Une case vide veut '
                      'dire « on ne sait pas », jamais zéro.',
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _readTiles(MealTotals totals) {
    String? grams(int? value) => value?.toString();
    return [
      AppNutrientTile(
        icon: AppIcons.nutrientEnergy,
        tint: AppColors.nutritionEnergy,
        label: 'Calories',
        unit: 'kcal',
        value: formatThousands(totals.kcal),
      ),
      AppNutrientTile(
        icon: AppIcons.protein,
        tint: AppColors.nutritionProtein,
        label: 'Protéines',
        unit: 'g',
        value: grams(totals.proteinG),
      ),
      AppNutrientTile(
        icon: AppIcons.nutrientCarbs,
        tint: AppColors.nutritionCarbs,
        label: 'Glucides',
        unit: 'g',
        value: grams(totals.carbsG),
      ),
      AppNutrientTile(
        icon: AppIcons.nutrientFat,
        tint: AppColors.nutritionFat,
        label: 'Lipides',
        unit: 'g',
        value: grams(totals.fatG),
      ),
    ];
  }

  static List<Widget> _entryTiles(
    MealEditorState state,
    MealEditorErrors errors,
    MealValueSetters setters,
  ) {
    Widget tile({
      required String text,
      required IconData icon,
      required Color tint,
      required String label,
      required String unit,
      required String? error,
      required ValueChanged<String> onChanged,
    }) => BoundText(
      text: text,
      builder: (controller) => AppNutrientTile.editable(
        icon: icon,
        tint: tint,
        label: label,
        unit: unit,
        controller: controller,
        errorText: error,
        onChanged: onChanged,
      ),
    );

    return [
      tile(
        text: state.kcalText,
        icon: AppIcons.nutrientEnergy,
        tint: AppColors.nutritionEnergy,
        label: 'Calories',
        unit: 'kcal',
        error: errors.kcal,
        onChanged: setters.kcal,
      ),
      tile(
        text: state.proteinText,
        icon: AppIcons.protein,
        tint: AppColors.nutritionProtein,
        label: 'Protéines',
        unit: 'g',
        error: errors.protein,
        onChanged: setters.protein,
      ),
      tile(
        text: state.carbsText,
        icon: AppIcons.nutrientCarbs,
        tint: AppColors.nutritionCarbs,
        label: 'Glucides',
        unit: 'g',
        error: errors.carbs,
        onChanged: setters.carbs,
      ),
      tile(
        text: state.fatText,
        icon: AppIcons.nutrientFat,
        tint: AppColors.nutritionFat,
        label: 'Lipides',
        unit: 'g',
        error: errors.fat,
        onChanged: setters.fat,
      ),
    ];
  }
}
