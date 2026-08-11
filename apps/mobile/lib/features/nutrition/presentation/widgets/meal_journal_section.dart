import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../domain/entities/nutrition.dart';
import '../controllers/nutrition_controllers.dart';
import 'add_meal_sheet.dart';

/// Le journal du jour : ce qui a été mangé, son total, et l'ajout.
///
/// C'est lui qui rend le « consommé / objectif » de l'accueil RÉEL — sans
/// journal, l'application n'aurait que l'objectif à montrer.
class MealJournalSection extends ConsumerWidget {
  const MealJournalSection({this.targetKcal, super.key});

  /// Objectif calorique du jour, si le profil métabolique le donne.
  final int? targetKcal;

  Future<void> _addMeal(BuildContext context, WidgetRef ref) async {
    final draft = await showAddMealSheet(context);
    if (draft == null) {
      return;
    }
    await ref.read(nutritionActionsProvider).addMeal(
          name: draft.name,
          kcal: draft.kcal,
          proteinG: draft.proteinG,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(todayMealsProvider);
    final consumed = ref.watch(consumedKcalTodayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Journal du jour',
          trailing: consumed == null
              ? null
              : targetKcal == null
                  ? '${formatThousands(consumed)} kcal'
                  : '${formatThousands(consumed)} / '
                      '${formatThousands(targetKcal!)} kcal',
        ),
        const SizedBox(height: AppSpacing.sm),
        meals.when(
          loading: () => const AppLoadingIndicator(),
          error: (error, _) => ConnectionAwareError(
            error: error,
            title: 'Journal indisponible',
            message: 'Tes repas n’ont pas pu être chargés.',
            offlineMessage: 'Le journal vit sur le serveur : tes repas '
                'reviendront avec le réseau.',
            onRetry: () => ref.invalidate(todayMealsProvider),
          ),
          data: (entries) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entries.isEmpty)
                AppCard(
                  child: Text(
                    'Rien au journal aujourd’hui. Ajoute ton premier repas '
                    'pour suivre ton objectif.',
                    style: AppTypography.body
                        .copyWith(color: AppColors.darkTextSecondary),
                  ),
                )
              else
                for (final meal in entries) ...[
                  _MealTile(
                    meal: meal,
                    onDelete: () =>
                        ref.read(nutritionActionsProvider).deleteMeal(meal.id),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Ajouter un repas',
                variant: AppButtonVariant.secondary,
                onPressed: () => _addMeal(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal, required this.onDelete});

  final MealEntry meal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final protein = meal.proteinG;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: AppTypography.subheading
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                Text(
                  '${formatThousands(meal.kcal)} kcal'
                  '${protein == null ? '' : ' · $protein g de protéines'}',
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Retirer ce repas',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.darkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
