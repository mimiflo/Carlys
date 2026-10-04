import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/meal_entry.dart';
import '../providers/meal_photo_provider.dart';
import 'meal_editor/meal_icons.dart';

/// Une ligne du journal : la photo du plat (ou le dessin de son moment),
/// le moment, l'heure et les calories, ce qu'on a mangé, puis ses trois
/// macros. Toucher la ligne ouvre le repas : on le corrige, ou on le
/// supprime, depuis son écran.
///
/// L'heure EXPLIQUE l'ordre de la liste, triée par instant de consommation :
/// sans elle, deux « Poulet riz » de la journée se confondaient.
class MealTile extends ConsumerWidget {
  const MealTile({required this.meal, required this.onEdit, super.key});

  final MealEntry meal;
  final VoidCallback onEdit;

  static const double _thumbnail = 64;
  static const double _momentIcon = 18;

  /// En dessous, les macros passent sous le texte au lieu d'à droite.
  static const double _sideBySideWidth = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moment = meal.displayedMoment;
    final savedAt = meal.photoUpdatedAt;
    final photo = savedAt == null
        ? null
        : ref.watch(mealPhotoProvider((mealId: meal.id, updatedAt: savedAt)));
    final bytes = photo?.valueOrNull;
    final when = [
      formatClock(meal.eatenAt.toLocal()),
      '${formatThousands(meal.kcal)} kcal',
      ?meal.spelledQuantity,
    ].join(' · ');

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(moment.icon, color: AppColors.primaryLight, size: _momentIcon),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                moment.label,
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
          ],
        ),
        Text(
          when,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        Text(
          meal.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
      ],
    );
    // Une macro inconnue ne s'écrit PAS « 0 g » : elle ne s'écrit pas du
    // tout. Le serveur distingue l'absence du zéro, l'écran aussi.
    final macros = Wrap(
      spacing: AppSpacing.xs,
      children: [
        if (meal.proteinG case final grams?)
          _Macro(
            grams: grams,
            label: 'Prot.',
            tint: AppColors.nutritionProtein,
          ),
        if (meal.carbsG case final grams?)
          _Macro(grams: grams, label: 'Gluc.', tint: AppColors.nutritionCarbs),
        if (meal.fatG case final grams?)
          _Macro(grams: grams, label: 'Lip.', tint: AppColors.nutritionFat),
      ],
    );

    return AppCard(
      onTap: onEdit,
      semanticLabel: 'Modifier ${moment.label} : ${meal.name}, $when',
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: [
          AppThumbnail(
            image: bytes == null ? null : MemoryImage(bytes),
            loading: photo?.isLoading ?? false,
            fallbackIcon: moment.icon,
            size: _thumbnail,
            semanticLabel: bytes == null ? moment.label : 'Photo du plat',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side =
                    constraints.maxWidth >=
                    MediaQuery.textScalerOf(context).scale(_sideBySideWidth);
                if (!side) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text,
                      const SizedBox(height: AppSpacing.xxs),
                      macros,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: text),
                    macros,
                  ],
                );
              },
            ),
          ),
          const Icon(AppIcons.chevronRight, color: AppColors.darkTextTertiary),
        ],
      ),
    );
  }
}

/// Une macro connue du repas : ses grammes et son nom court.
class _Macro extends StatelessWidget {
  const _Macro({required this.grams, required this.label, required this.tint});

  final int grams;
  final String label;
  final Color tint;

  static const double _width = 48;

  @override
  Widget build(BuildContext context) {
    // Une largeur MINIMALE : les trois colonnes s'alignent, et grandissent
    // avec le texte au lieu de couper « Prot. » en deux.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: _width),
      child: Column(
        children: [
          Text(
            '$grams g',
            style: AppTypography.subheading.copyWith(color: tint),
          ),
          Text(label, style: AppTypography.label.copyWith(color: tint)),
        ],
      ),
    );
  }
}
