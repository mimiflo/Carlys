import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../providers/journal_day_provider.dart';
import '../providers/nutrition_providers.dart';
import 'meal_editor/food_source_mention.dart';
import 'meal_tile.dart';

/// « Journal alimentaire » : les repas du jour affiché (choisi en haut de
/// la page), et la mention de la table d'aliments quand ses valeurs y
/// figurent. Toucher un repas l'ouvre : on le corrige ou on le supprime
/// depuis son écran, qui garde son identifiant et sa place dans la liste.
///
/// C'est lui qui rend le « consommé / objectif » de l'accueil RÉEL — sans
/// journal, l'application n'aurait que l'objectif à montrer.
class MealJournalSection extends ConsumerWidget {
  const MealJournalSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(journalDayProvider);
    final meals = ref.watch(mealsForDayProvider(day));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'Journal alimentaire'),
        const SizedBox(height: AppSpacing.xs),
        meals.when(
          loading: () => const AppLoadingIndicator(),
          error: (error, _) => ConnectionAwareError(
            error: error,
            title: 'Journal indisponible',
            message: 'Tes repas n’ont pas pu être chargés.',
            offlineMessage:
                'Le journal vit sur le serveur : tes repas '
                'reviendront avec le réseau.',
            onRetry: () => ref.invalidate(mealsForDayProvider(day)),
          ),
          data: (journee) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (journee.meals.isEmpty)
                AppEmptyState(
                  icon: AppIcons.nutrition,
                  title: 'Rien au journal ce jour-là',
                  message: 'Ajoute un repas pour suivre ton objectif.',
                  actionLabel: 'Ajouter un repas',
                  onAction: () => context.push(AppRoutes.newMeal(day: day)),
                )
              else
                for (final meal in journee.meals) ...[
                  MealTile(
                    meal: meal,
                    onEdit: () => context.push(AppRoutes.meal(meal.id)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              // Des totaux calculés depuis la table CIQUAL : sa mention les
              // accompagne, comme partout où une valeur de la base se montre
              // (licence Etalab 2.0, CGU).
              if (journee.attribution case final attribution?)
                FoodSourceMention(
                  attribution: attribution,
                  versions: [
                    for (final meal in journee.meals)
                      for (final line in meal.components) ?line.sourceVersion,
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
