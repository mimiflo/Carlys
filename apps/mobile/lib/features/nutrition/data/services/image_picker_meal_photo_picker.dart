import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/meal_photo.dart';
import '../../domain/meal_bounds.dart';
import '../../domain/services/meal_photo_picker.dart';
import 'meal_photo_preparation.dart';
import 'picker_copies.dart';

/// Le port [MealPhotoPicker] sur le greffon officiel `image_picker`.
///
/// Deux étages, et chacun fait ce qu'il fait le mieux :
///
/// 1. `image_picker` ouvre l'appareil photo ou la galerie et livre une
///    PREMIÈRE réduction native à 1 600 px (une photo de 12 Mpx n'entre
///    jamais entière en mémoire Dart). Il laisse souvent l'étiquette
///    d'orientation EXIF à côté de pixels couchés (Android la recopie après
///    réduction) : ce n'est pas lui qui redresse.
/// 2. [prepareMealPhoto], en pur Dart, dans un ISOLAT (un décodage ne doit
///    pas figer l'écran) : redresse, réduit au besoin, réencode sans
///    métadonnées, sous 5 Mio.
///
/// iOS ne demande la permission de la galerie que pour en lire les
/// métadonnées : `requestFullMetadata: false` s'en passe, le sélecteur
/// système suffit. L'appareil photo, lui, demande toujours.
class ImagePickerMealPhotoPicker implements MealPhotoPicker {
  ImagePickerMealPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static final _logger = AppLogger('MealPhotoPicker');

  /// La qualité de la réduction NATIVE : haute, puisque [prepareMealPhoto]
  /// réencode ensuite ; plus basse, la photo serait compressée deux fois.
  static const int _nativeQuality = 92;

  @override
  Future<Uint8List?> pick(MealPhotoSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: switch (source) {
          MealPhotoSource.camera => ImageSource.camera,
          MealPhotoSource.gallery => ImageSource.gallery,
        },
        maxWidth: MealBounds.photoMaxSide.toDouble(),
        maxHeight: MealBounds.photoMaxSide.toDouble(),
        imageQuality: _nativeQuality,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      throw MealPhotoException(_failureOf(error), error);
    }
    if (file == null) {
      return null;
    }
    final original = await file.readAsBytes();
    // Seuls les octets préparés doivent survivre, et seulement en mémoire :
    // la copie rendue part, et sous Android l'ORIGINALE aussi — le greffon
    // la laisse dans le cache, position GPS comprise (voir
    // [discardPickerCopies]). Un échec n'empêche pas la photo de partir.
    await discardPickerCopies(
      file.path,
      sweepOriginals: Platform.isAndroid,
      onFailure: (error) => _logger.warning(
        'Copie temporaire de la photo non effacée',
        error: error,
      ),
    );
    return Isolate.run(() => prepareMealPhoto(original));
  }

  /// Les codes d'erreur des deux greffons : `camera_access_denied`,
  /// `photo_access_denied` (refus), `no_available_camera`,
  /// `invalid_image`…
  static MealPhotoFailure _failureOf(PlatformException error) {
    if (error.code.endsWith('access_denied')) {
      return MealPhotoFailure.permissionDenied;
    }
    if (error.code == 'invalid_image') {
      return MealPhotoFailure.unreadable;
    }
    return MealPhotoFailure.unavailable;
  }
}

/// L'appareil photo et la galerie — remplacés par un faux dans les tests.
final mealPhotoPickerProvider = Provider<MealPhotoPicker>(
  (ref) => ImagePickerMealPhotoPicker(),
);
