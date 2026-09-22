import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feedback/server_gesture.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../domain/entities/meal_entry.dart';
import '../controllers/nutrition_controllers.dart';
import '../meal_entry_flow.dart';
import '../providers/journal_day_provider.dart';
import 'add_meal_sheet.dart';
import 'meal_day_selector.dart';
import 'meal_tile.dart';

/// Le journal d'un jour : ce qui a été mangé, son total, et ce qu'on peut y
/// faire — ajouter, corriger, retirer.
///
/// C'est lui qui rend le « consommé / objectif » de l'accueil RÉEL — sans
/// journal, l'application n'aurait que l'objectif à montrer.
class MealJournalSection extends ConsumerWidget {
  const MealJournalSection({this.targetKcal, super.key});

  /// Objectif calorique du jour, si le profil métabolique le donne.
  final int? targetKcal;

  /// Le journal vit sur le SERVEUR — l'écran le dit lui-même plus bas. Un
  /// ajout, une correction ou une suppression qui échoue doit donc se voir :
  /// la feuille s'est déjà refermée, la liste ne bouge pas, et rien ne
  /// distinguerait « refusé » de « déjà enregistré ».
  ///
  /// L'AJOUT, lui, est parti dans `meal_entry_flow.dart` : l'accueil ouvre la
  /// même porte depuis sa tuile de calories, et deux copies d'un geste
  /// d'écriture divergent toujours par où ça se voit le plus.

  /// Corriger, plutôt que supprimer puis ressaisir : le repas garde son
  /// identifiant, sa place dans la liste, et ne disparaît pas du total entre
  /// les deux gestes.
  Future<void> _editMeal(
    BuildContext context,
    WidgetRef ref,
    MealEntry meal,
  ) async {
    final draft = await showMealSheet(context, existing: meal);
    if (draft == null || !context.mounted) {
      return;
    }
    await runServerGesture(context, () async {
      await ref
          .read(nutritionActionsProvider)
          .updateMeal(
            meal.id,
            MealCorrection(
              name: draft.name,
              kcal: draft.kcal,
              eatenAt: draft.eatenAt,
              quantity: draft.quantity,
              quantityUnit: draft.quantityUnit,
              proteinG: draft.proteinG,
              carbsG: draft.carbsG,
              fatG: draft.fatG,
            ),
          );
      return null;
    }, scope: 'MealJournal');
  }

  Future<void> _deleteMeal(BuildContext context, WidgetRef ref, String id) {
    return runServerGesture(context, () async {
      await ref.read(nutritionActionsProvider).deleteMeal(id);
      return null;
    }, scope: 'MealJournal');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(journalDayProvider);
    final meals = ref.watch(mealsForDayProvider(day));
    final consumed = meals.valueOrNull?.fold<int>(
      0,
      (sum, meal) => sum + meal.kcal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Journal',
          trailing: consumed == null
              ? null
              : targetKcal == null
              ? '${formatThousands(consumed)} kcal'
              : '${formatThousands(consumed)} / '
                    '${formatThousands(targetKcal!)} kcal',
        ),
        const MealDaySelector(),
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
          data: (entries) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entries.isEmpty)
                AppCard(
                  child: Text(
                    'Rien au journal ce jour-là. Ajoute un repas pour suivre '
                    'ton objectif.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                )
              else
                for (final meal in entries) ...[
                  MealTile(
                    meal: meal,
                    onEdit: () => _editMeal(context, ref, meal),
                    onDelete: () => _deleteMeal(context, ref, meal.id),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Ajouter un repas',
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    noteUnRepas(context, ref, day: day, scope: 'MealJournal'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
