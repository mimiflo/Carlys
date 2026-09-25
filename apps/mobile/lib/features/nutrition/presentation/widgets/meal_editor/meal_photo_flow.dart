import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import '../../controllers/meal_editor_controller.dart';
import 'meal_photo_sheet.dart';

/// Le bouton appareil photo de la vignette : la feuille d'options, puis la
/// prise (ou le choix) et la préparation de la photo par le contrôleur.
///
/// La photo ne part PAS d'ici : elle attend l'enregistrement du repas, dont
/// sa route a besoin. Chaque échec se DIT, avec sa cause : un accès refusé
/// n'est pas une image illisible.
Future<void> pickMealPhoto(
  BuildContext context,
  WidgetRef ref,
  MealEditorKey key,
) async {
  final editor = ref.read(mealEditorProvider(key)).valueOrNull;
  if (editor == null || editor.isBusy) {
    return;
  }
  final notices = AppNotices.of(context);
  final choice = await showMealPhotoSheet(context, hasPhoto: editor.hasPhoto);
  if (choice == null || !context.mounted) {
    return;
  }
  final controller = ref.read(mealEditorProvider(key).notifier);
  final source = switch (choice) {
    MealPhotoChoice.take => MealPhotoSource.camera,
    MealPhotoChoice.choose => MealPhotoSource.gallery,
    MealPhotoChoice.remove => null,
  };
  if (source == null) {
    controller.removePhoto();
    notices.show('La photo sera retirée à l’enregistrement du repas.');
    return;
  }
  try {
    await controller.pickPhoto(source);
  } on MealPhotoException catch (error) {
    notices.show(
      mealPhotoFailureMessage(error.failure, source),
      tone: AppNoticeTone.error,
    );
  } on Exception {
    notices.show(
      'La photo n’a pas pu être préparée. Réessaie, ou choisis-en une autre.',
      tone: AppNoticeTone.error,
    );
  }
}

/// Ce que l'écran dit d'une photo qui n'a pas pu être prise ou préparée.
String mealPhotoFailureMessage(
  MealPhotoFailure failure,
  MealPhotoSource source,
) {
  return switch ((failure, source)) {
    (MealPhotoFailure.permissionDenied, MealPhotoSource.camera) =>
      'Carlys n’a pas accès à l’appareil photo. Autorise-le dans les '
          'réglages du téléphone, ou choisis une photo dans la galerie.',
    (MealPhotoFailure.permissionDenied, MealPhotoSource.gallery) =>
      'Carlys n’a pas accès à tes photos. Autorise-le dans les réglages du '
          'téléphone, ou prends une photo.',
    (MealPhotoFailure.unreadable, _) =>
      'Cette image ne se lit pas : choisis-en une autre.',
    (MealPhotoFailure.tooLarge, _) =>
      'Cette image reste trop lourde, même réduite : choisis-en une autre.',
    (MealPhotoFailure.unavailable, MealPhotoSource.camera) =>
      'L’appareil photo n’a pas pu s’ouvrir. Réessaie, ou choisis une photo '
          'dans la galerie.',
    (MealPhotoFailure.unavailable, MealPhotoSource.gallery) =>
      'La galerie n’a pas pu s’ouvrir. Réessaie, ou prends une photo.',
  };
}
