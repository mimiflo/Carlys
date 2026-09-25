import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/server_gesture.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../controllers/nutrition_controllers.dart';
import '../providers/journal_day_provider.dart';
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

  /// Le journal vit sur le SERVEUR — l'écran le dit lui-même plus bas. Une
  /// suppression qui échoue doit donc se voir : la liste ne bouge pas, et
  /// rien ne distinguerait « refusé » de « déjà retiré ».
  ///
  /// Ajouter et corriger ouvrent l'écran plein « Ajouter / Modifier ce
  /// repas » ; l'accueil ouvre le même depuis sa tuile de calories. Corriger
  /// plutôt que supprimer puis ressaisir : le repas garde son identifiant, sa
  /// place dans la liste, et ne disparaît pas du total entre les deux gestes.
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
                    onEdit: () => context.push(AppRoutes.meal(meal.id)),
                    onDelete: () => _deleteMeal(context, ref, meal.id),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Ajouter un repas',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(AppRoutes.newMeal(day: day)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
