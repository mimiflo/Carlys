import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';

/// Ce que la personne veut faire de la photo du plat.
enum MealPhotoChoice { take, choose, remove }

/// La feuille du bouton appareil photo : « Prendre une photo », « Choisir
/// dans la galerie », et « Retirer la photo » quand il y en a une. Rend
/// `null` si la personne renonce.
///
/// Rien n'est envoyé d'ici : le choix se prépare sur l'appareil, et part à
/// l'enregistrement du repas.
Future<MealPhotoChoice?> showMealPhotoSheet(
  BuildContext context, {
  required bool hasPhoto,
}) {
  return showAppSheet<MealPhotoChoice>(
    context,
    style: AppSheetStyle.picker,
    builder: (sheetContext) {
      void choose(MealPhotoChoice choice) =>
          Navigator.of(sheetContext).pop(choice);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Photo du plat',
              style: AppTypography.subheading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Elle reste privée : toi seul la vois. Elle est redressée et '
              'allégée sur ton téléphone, sans la position ni le modèle de '
              'l’appareil.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppListRow(
              title: 'Prendre une photo',
              leading: AppIcons.mealPhoto,
              onTap: () => choose(MealPhotoChoice.take),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppListRow(
              title: 'Choisir dans la galerie',
              leading: AppIcons.mealPhotoGallery,
              onTap: () => choose(MealPhotoChoice.choose),
            ),
            if (hasPhoto) ...[
              const SizedBox(height: AppSpacing.xs),
              AppListRow(
                title: 'Retirer la photo',
                leading: AppIcons.mealPhotoRemove,
                onTap: () => choose(MealPhotoChoice.remove),
              ),
            ],
          ],
        ),
      );
    },
  );
}
