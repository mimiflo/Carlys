import 'dart:async';
import 'dart:typed_data';

import 'package:carlys_mobile/features/nutrition/domain/entities/meal_photo.dart';
import 'package:carlys_mobile/features/nutrition/domain/services/meal_photo_picker.dart';

/// L'appareil photo et la galerie des tests : aucun greffon, une réponse
/// réglée d'avance.
class FakeMealPhotoPicker implements MealPhotoPicker {
  FakeMealPhotoPicker({this.photo, this.failure});

  /// Ce que la prochaine prise rend (déjà « préparé ») ; `null` : la
  /// personne renonce.
  Uint8List? photo;

  /// L'échec que la prochaine prise oppose ; consommé par elle.
  MealPhotoException? failure;

  /// Retient la prochaine prise jusqu'à ce que le test le complète : de
  /// quoi voir l'écran PENDANT la préparation de la photo.
  Completer<void>? hold;

  /// Chaque demande, dans l'ordre : l'appareil photo ou la galerie.
  final List<MealPhotoSource> requests = [];

  @override
  Future<Uint8List?> pick(MealPhotoSource source) async {
    requests.add(source);
    final held = hold;
    if (held != null) {
      hold = null;
      await held.future;
    }
    final refused = failure;
    if (refused != null) {
      failure = null;
      throw refused;
    }
    return photo;
  }
}
