import 'dart:typed_data';

import '../entities/meal_photo.dart';

/// Frontière UNIQUE avec l'appareil photo et la galerie.
///
/// Tout ce qui se passe AUTOUR de la photo (la feuille d'options, l'envoi
/// après l'enregistrement, l'échec signalé) se teste contre un faux qui
/// implémente ce port : aucun test n'appelle de greffon, et changer de
/// greffon ne toucherait qu'un fichier.
abstract interface class MealPhotoPicker {
  /// Prend ([MealPhotoSource.camera]) ou choisit
  /// ([MealPhotoSource.gallery]) une photo, et la rend PRÊTE À L'ENVOI :
  /// redressée (l'orientation appliquée aux pixels), réduite, réencodée en
  /// JPEG sans métadonnées, sous la taille que le serveur accepte.
  ///
  /// `null` si la personne renonce : ce n'est pas une erreur. Lève
  /// [MealPhotoException] quand l'accès est refusé, que l'image ne se lit
  /// pas, ou que l'appareil photo ne s'ouvre pas.
  Future<Uint8List?> pick(MealPhotoSource source);
}
