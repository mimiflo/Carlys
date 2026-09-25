/// La PHOTO d'un repas, côté appareil : d'où elle vient, ce que l'écran
/// compte en faire à l'enregistrement, et pourquoi elle a pu manquer.
///
/// La photo elle-même vit sur le serveur, privée (`…/meals/:id/photo`) ;
/// l'appareil ne garde que ce qu'il vient de préparer, le temps de l'envoyer.
library;

import 'dart:typed_data';

/// D'où vient une photo neuve.
enum MealPhotoSource {
  /// L'appareil photo, tout de suite.
  camera,

  /// Une photo déjà prise, dans la galerie.
  gallery,
}

/// Ce que l'écran fera de la photo à l'ENREGISTREMENT.
///
/// Rien ne part avant : la route de la photo a besoin d'un repas écrit, et
/// renoncer à l'écran ne doit rien avoir envoyé.
sealed class MealPhotoChange {
  const MealPhotoChange();
}

/// On ne touche pas à la photo (celle du serveur, ou aucune).
final class KeepMealPhoto extends MealPhotoChange {
  const KeepMealPhoto();
}

/// Une photo neuve, DÉJÀ préparée : redressée, réduite, réencodée en JPEG
/// sans métadonnées. Ce sont ces octets-là qui partiront, tels quels.
final class NewMealPhoto extends MealPhotoChange {
  const NewMealPhoto(this.jpeg);

  final Uint8List jpeg;
}

/// On retire la photo du serveur.
final class RemoveMealPhoto extends MealPhotoChange {
  const RemoveMealPhoto();
}

/// Pourquoi une photo n'a pas pu être prise ou préparée.
enum MealPhotoFailure {
  /// L'accès à l'appareil photo ou aux photos a été refusé.
  permissionDenied,

  /// Le fichier choisi ne se lit pas comme une image (format inconnu,
  /// fichier tronqué).
  unreadable,

  /// Même réduite au plus petit, l'image dépasse ce que le serveur accepte.
  tooLarge,

  /// L'appareil photo ou la galerie n'a pas pu s'ouvrir (pas d'appareil
  /// photo, panne du système).
  unavailable,
}

/// L'échec d'une prise ou d'une préparation de photo, avec sa cause : c'est
/// elle que l'écran dit, pas un « échec » générique.
class MealPhotoException implements Exception {
  const MealPhotoException(this.failure, [this.detail]);

  final MealPhotoFailure failure;

  /// Le détail technique, pour le journal ; jamais affiché.
  final Object? detail;

  @override
  String toString() => 'MealPhotoException($failure, $detail)';
}
