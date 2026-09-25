import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../../../shared/widgets/connection_aware_error.dart';
import '../../../domain/entities/nutrition.dart';
import '../../controllers/food_search_controller.dart';
import 'food_result_row.dart';

/// Ce que la feuille de recherche montre SOUS le champ, dans chacun de ses
/// états : l'invitation à chercher, le chargement, l'erreur (hors connexion
/// ou panne, avec « Réessayer »), la base pas encore chargée, l'absence de
/// résultat, et les résultats.
///
/// Rendu en LISTE d'éléments plutôt qu'en widget : la feuille les pose dans
/// sa propre liste défilante, seule ou avec l'en-tête quand la place manque
/// (petit écran, grand texte, clavier ouvert).
List<Widget> foodSearchEntries({
  required FoodSearchState state,
  required VoidCallback onRetry,
  required VoidCallback onManual,
  required ValueChanged<Food> onPick,
}) {
  if (state.isDatabaseEmpty) {
    return [
      AppEmptyState(
        icon: AppIcons.foodDatabasePending,
        title: 'Base d’aliments en préparation',
        message:
            'La base d’aliments arrive bientôt : saisis les valeurs à la '
            'main.',
        actionLabel: 'Saisir à la main',
        onAction: onManual,
      ),
    ];
  }
  switch (state.status) {
    case FoodSearchStatus.idle:
      return const [
        AppEmptyState(
          icon: AppIcons.search,
          title: 'Cherche un aliment',
          message:
              'Deux lettres suffisent pour commencer : « poulet », « riz », '
              '« yaourt »…',
        ),
      ];
    case FoodSearchStatus.failed:
      return [
        ConnectionAwareError(
          error: state.error ?? const Object(),
          title: 'Recherche indisponible',
          message:
              'La base d’aliments n’a pas répondu. Réessaie, ou saisis les '
              'valeurs à la main.',
          offlineMessage:
              'La base d’aliments vit sur le serveur : elle revient avec le '
              'réseau. En attendant, saisis les valeurs à la main.',
          onRetry: onRetry,
        ),
      ];
    case FoodSearchStatus.loading when state.foods.isEmpty:
      return const [AppLoadingIndicator(label: 'Recherche en cours')];
    case FoodSearchStatus.ready when state.foods.isEmpty:
      return [
        AppEmptyState(
          title: 'Aucun aliment pour « ${state.query} »',
          message:
              'Essaie un mot plus simple (« poulet » plutôt que « blanc de '
              'poulet »), ou saisis les valeurs à la main.',
          actionLabel: 'Saisir à la main',
          onAction: onManual,
        ),
      ];
    case FoodSearchStatus.loading || FoodSearchStatus.ready:
      return [
        // Les résultats PRÉCÉDENTS restent pendant qu'une nouvelle
        // recherche part : la barre dit qu'ils vont changer.
        if (state.status == FoodSearchStatus.loading)
          const LinearProgressIndicator(semanticsLabel: 'Recherche en cours'),
        for (final (index, food) in state.foods.indexed) ...[
          if (index > 0)
            const Divider(height: AppSpacing.xs, color: AppColors.rowDivider),
          FoodResultRow(
            key: ValueKey(food.code),
            food: food,
            onTap: () => onPick(food),
          ),
        ],
      ];
  }
}
