import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/meal_bounds.dart';
import '../../domain/services/packaged_meal.dart';
import '../providers/nutrition_providers.dart';
import '../utils/meal_editor_outcome.dart';
import '../utils/meal_editor_state.dart';
import '../utils/meal_editor_validation.dart';
import 'meal_editor/food_source_mention.dart';

/// Le produit scanné, prêt à entrer au journal : la quantité mangée (une
/// portion de l'emballage, ou 100), ses valeurs recalculées à chaque
/// chiffre, et la mention de la base.
class ScannedProductForm extends ConsumerStatefulWidget {
  const ScannedProductForm({
    required this.result,
    required this.day,
    super.key,
  });

  final PackagedFoodResult result;

  /// Le jour du journal : le repas y est daté.
  final DateTime day;

  @override
  ConsumerState<ScannedProductForm> createState() => _ScannedProductFormState();
}

class _ScannedProductFormState extends ConsumerState<ScannedProductForm> {
  late final TextEditingController _quantity = TextEditingController(
    text: formatQuantityInput(widget.result.food.servingQuantity ?? 100),
  );

  /// Né à l'ouverture : un ajout qui échoue puis se rejoue garde le même
  /// identifiant, et le serveur ne fait pas de doublon.
  final String _mealId = const Uuid().v4();
  bool _tried = false;
  bool _saving = false;

  static const double _tileWidth = 72;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  /// La règle d'une quantité d'aliment, celle de l'écran de repas : de 1 à
  /// 5 000, deux décimales au plus (le serveur refuse au-delà).
  double? get _parsed => componentQuantityError(_quantity.text) == null
      ? parseDecimalInput(_quantity.text)
      : null;

  Future<void> _add(double quantity) async {
    final notices = AppNotices.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final write = packagedMeal(
        widget.result.food,
        quantity,
        initialMealInstant(widget.day, DateTime.now()),
      );
      await ref
          .read(nutritionActionsProvider)
          .addMeal(_mealId, write, mayExist: _tried);
      notices.show('Ajouté au journal.', tone: AppNoticeTone.success);
      // La feuille a pu être fermée pendant l'envoi : ne rien dépiler d'autre.
      if (mounted) navigator.pop(true);
    } on Exception catch (error) {
      _tried = true;
      if (mounted) setState(() => _saving = false);
      notices.show(
        error is NetworkException
            ? 'Hors ligne : le repas n’est pas parti. Réessaie avec le réseau.'
            : 'Le repas n’a pas pu être ajouté. Réessaie.',
        tone: AppNoticeTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.result.food;
    final unit = food.liquid ? 'ml' : 'g';
    final quantity = _parsed;
    final amounts = quantity == null ? null : packagedAmounts(food, quantity);
    final kcal = amounts?.kcal;
    // Les bornes du journal (celles du serveur) : mieux vaut éteindre le
    // bouton qu'encaisser un refus après coup.
    bool fits(int? grams) => grams == null || grams <= MealBounds.macroMaxG;
    final ready =
        amounts != null &&
        amounts.kcal >= MealBounds.kcalMin &&
        amounts.kcal <= MealBounds.kcalMax &&
        fits(amounts.proteinG) &&
        fits(amounts.carbsG) &&
        fits(amounts.fatG);
    String? grams(int? value) => value?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          food.name,
          style: AppTypography.heading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        if (food.brand case final brand?)
          Text(
            brand,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Pour 100 $unit : ${formatDecimal(food.per100g.kcal, decimals: 0)} kcal',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: food.liquid ? 'Quantité bue' : 'Quantité mangée',
          controller: _quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffixText: unit,
          errorText: quantity == null
              ? 'De 1 à ${formatThousands(5000)} $unit, deux décimales au plus.'
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppAdaptiveGrid(
          minItemWidth: _tileWidth,
          children: [
            AppNutrientTile(
              icon: AppIcons.nutrientEnergy,
              tint: AppColors.nutritionEnergy,
              label: 'Calories',
              unit: 'kcal',
              value: kcal == null ? null : formatThousands(kcal),
            ),
            AppNutrientTile(
              icon: AppIcons.protein,
              tint: AppColors.nutritionProtein,
              label: 'Protéines',
              unit: 'g',
              value: grams(amounts?.proteinG),
            ),
            AppNutrientTile(
              icon: AppIcons.nutrientCarbs,
              tint: AppColors.nutritionCarbs,
              label: 'Glucides',
              unit: 'g',
              value: grams(amounts?.carbsG),
            ),
            AppNutrientTile(
              icon: AppIcons.nutrientFat,
              tint: AppColors.nutritionFat,
              label: 'Lipides',
              unit: 'g',
              value: grams(amounts?.fatG),
            ),
          ],
        ),
        if (amounts != null && !ready) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            amounts.kcal < MealBounds.kcalMin
                ? 'Pas une calorie dans cette quantité : rien à compter au '
                      'journal.'
                : 'Au-delà de ce qu’un repas peut compter '
                      '(${formatThousands(MealBounds.kcalMax)} kcal, '
                      '${formatThousands(MealBounds.macroMaxG)} g par macro).',
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        FoodSourceMention(
          attribution: widget.result.source,
          versions: const [],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Ajouter au journal',
          icon: AppIcons.check,
          isExpanded: true,
          isLoading: _saving,
          onPressed: ready && !_saving && quantity != null
              ? () => _add(quantity)
              : null,
        ),
      ],
    );
  }
}
