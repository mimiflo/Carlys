import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import '../../../domain/meal_bounds.dart';
import '../../controllers/food_search_controller.dart';
import '../../utils/meal_editor_state.dart';
import '../../utils/meal_editor_validation.dart';
import 'food_search_results.dart';
import 'food_source_mention.dart';

/// Ce que la feuille rapporte : l'aliment, sa quantité en grammes, et la
/// mention de la base d'où viennent ses valeurs (version comprise).
typedef FoodPick = ({Food food, double grams, FoodSource source});

/// « Ajouter un aliment » : chercher dans la base CIQUAL, toucher un
/// résultat, dire combien de grammes. Rend `null` si la personne renonce.
Future<FoodPick?> showFoodSearchSheet(BuildContext context) {
  return showAppSheet<FoodPick>(
    context,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: _FoodSearchSheet(),
    ),
  );
}

class _FoodSearchSheet extends ConsumerStatefulWidget {
  const _FoodSearchSheet();

  @override
  ConsumerState<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<_FoodSearchSheet> {
  final _query = TextEditingController();

  /// La hauteur, en points de texte, sous laquelle l'en-tête et la mention
  /// défilent AVEC les résultats plutôt que de rester fixes : sur un petit
  /// écran, en grand texte et clavier ouvert, trois blocs fixes ne
  /// laisseraient plus rien aux résultats.
  static const double _roomyHeight = 420;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Un résultat touché : sa quantité, par-dessus la feuille. Renoncer
  /// ramène aux résultats ; valider referme la feuille avec l'aliment.
  Future<void> _choose(Food food, FoodSource source) async {
    final navigator = Navigator.of(context);
    final raw = await showAppPrompt(
      context,
      title: 'Quantité de ${food.shortName}',
      message:
          '${food.name} : ${food.per100g.kcal.round()} kcal pour 100 g. '
          'En grammes, de 1 à 5 000.',
      initialValue: formatQuantityInput(MealBounds.componentDefaultG),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      suffixText: 'g',
      icon: AppIcons.mealQuantity,
      confirmLabel: 'Ajouter',
      validator: componentQuantityError,
    );
    final grams = raw == null ? null : parseDecimalInput(raw);
    if (grams == null || !mounted) {
      return;
    }
    navigator.pop<FoodPick>((food: food, grams: grams, source: source));
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(foodSearchProvider);
    final controller = ref.read(foodSearchProvider.notifier);
    final source = search.source;
    final entries = foodSearchEntries(
      state: search,
      onRetry: controller.retry,
      onManual: () => Navigator.of(context).pop(),
      onPick: (food) {
        if (source != null) {
          unawaited(_choose(food, source));
        }
      },
    );
    final header = <Widget>[
      Text(
        'Ajouter un aliment',
        style: AppTypography.subheading.copyWith(
          color: AppColors.darkTextPrimary,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppSearchField(
        controller: _query,
        onChanged: controller.search,
        hint: 'Poulet, riz, brocoli…',
        semanticLabel: 'Rechercher un aliment',
        autofocus: true,
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
    // La mention de la base, que la licence exige là où l'on cherche : dès
    // qu'une réponse l'a donnée, et tant que la base n'est pas vide (sans
    // valeur de la table, rien à attribuer).
    final mention = source == null || source.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: FoodSourceMention(
              attribution: source,
              versions: [?source.version],
            ),
          );

    const padding = EdgeInsets.all(AppSpacing.md);
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy =
            constraints.maxHeight >=
            MediaQuery.textScalerOf(context).scale(_roomyHeight);
        if (!roomy) {
          return ListView(
            padding: padding,
            children: [...header, ...entries, ?mention],
          );
        }
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...header,
              Expanded(child: ListView(children: entries)),
              ?mention,
            ],
          ),
        );
      },
    );
  }
}
