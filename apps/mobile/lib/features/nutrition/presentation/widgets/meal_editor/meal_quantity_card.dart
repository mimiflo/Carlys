import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import '../../utils/meal_editor_state.dart';
import 'bound_text.dart';

/// La carte QUANTITÉ : combien, et dans quelle unité.
///
/// Deux régimes, qui ne se mélangent pas :
///  - repas SAISI : la quantité est DESCRIPTIVE, l'unité se choisit, et le
///    texte sous la case le dit — « 250 g » à côté de « 350 kcal » se lirait
///    sinon comme « 350 kcal pour 100 g » ;
///  - repas COMPOSÉ : la quantité est la somme des aliments, en grammes ; la
///    case se lit sans se modifier, et l'unité reste sur « g ».
class MealQuantityCard extends StatelessWidget {
  const MealQuantityCard({
    required this.text,
    required this.unit,
    required this.computed,
    required this.error,
    required this.onText,
    required this.onUnit,
    super.key,
  });

  /// La quantité telle qu'elle s'écrit dans la case.
  final String text;
  final MealQuantityUnit unit;

  /// Vrai pour un repas composé : case en lecture seule, unité verrouillée.
  final bool computed;
  final String? error;
  final ValueChanged<String> onText;
  final ValueChanged<MealQuantityUnit> onUnit;

  @override
  Widget build(BuildContext context) {
    final shown = computed ? MealQuantityUnit.gram : unit;
    return AppTitledCard(
      icon: AppIcons.mealQuantity,
      title: 'Quantité',
      trailing: AppChoicePills<MealQuantityUnit>(
        choices: [
          for (final value in MealQuantityUnit.values)
            AppChoice(value, value.label, semanticLabel: value.longName),
        ],
        selected: shown,
        onSelected: computed ? null : onUnit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoundText(
            text: text,
            builder: (controller) => AppTextField(
              label: 'Quantité (${shown.longName})',
              controller: controller,
              hint: computed ? null : 'facultatif',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              readOnly: computed,
              suffixText: shown.suffixFor(parseDecimalInput(text)),
              errorText: computed ? null : error,
              onChanged: computed ? null : onText,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // Sous la quantité, CE qu'elle additionne ; « Calculé à partir
            // des aliments. », sous les valeurs, dit déjà d'où viennent les
            // nombres : la même phrase deux fois se lisait comme un doublon.
            computed
                ? 'La somme des aliments du repas.'
                : 'La quantité décrit ton assiette : elle ne multiplie pas '
                      'les calories saisies, qui restent celles du repas '
                      'entier.',
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
