/// La PRÉPARATION d'une photo de repas avant l'envoi, en pur Dart : une
/// fonction de données, sans greffon ni interface, donc testable sur de
/// vrais octets.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../domain/entities/meal_photo.dart';
import '../../domain/meal_bounds.dart';

/// Rend [original] (JPEG, PNG, WebP… tel que la galerie ou l'appareil photo
/// l'a livré) PRÊT À L'ENVOI : un JPEG droit, réduit, sans métadonnées, sous
/// [maxBytes].
///
/// Trois opérations, dans cet ordre, et chacune a sa raison :
///
/// 1. **Redresser.** Un téléphone tenu debout enregistre souvent les pixels
///    COUCHÉS, avec une simple étiquette EXIF « tourner de 90° ». Le serveur
///    retire toutes les métadonnées, l'étiquette comprise : sans ce
///    redressement, le plat s'afficherait couché. L'orientation est donc
///    appliquée AUX PIXELS, ici : le décodeur JPEG du paquet `image` le fait
///    en décodant, et `bakeOrientation` couvre les autres formats porteurs
///    d'EXIF (WebP, TIFF). Le test le prouve sur une vraie photo couchée.
/// 2. **Réduire** à [maxSide] points sur le plus grand côté, jamais agrandir.
/// 3. **Réencoder** en JPEG qualité [quality], SANS AUCUNE métadonnée : ni
///    position GPS, ni appareil, ni date ne quittent le téléphone (le
///    serveur les retirerait, mais ce qui ne part pas ne peut pas fuir).
///
/// Si le résultat dépasse [maxBytes] (une image très bruitée), la qualité
/// baisse, puis la taille : le serveur coupe à 5 Mio pendant la réception,
/// et une photo refusée après une longue attente ne dirait pas pourquoi.
///
/// Lève [MealPhotoException] ([MealPhotoFailure.unreadable]) quand les octets
/// ne sont pas une image lisible, et ([MealPhotoFailure.tooLarge]) si même
/// la plus petite version dépasse [maxBytes].
Uint8List prepareMealPhoto(
  Uint8List original, {
  int maxSide = MealBounds.photoMaxSide,
  int quality = MealBounds.photoQuality,
  int maxBytes = MealBounds.photoMaxBytes,
}) {
  final img.Image? decoded;
  try {
    // La PREMIÈRE image seulement : un GIF animé n'a qu'un plat à montrer.
    decoded = img.decodeImage(original, frame: 0);
  } on Object catch (error) {
    throw MealPhotoException(MealPhotoFailure.unreadable, error);
  }
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    throw const MealPhotoException(MealPhotoFailure.unreadable);
  }

  final upright = _flatten(img.bakeOrientation(decoded));
  // Toute métadonnée part ICI : `bakeOrientation` garde le reste de l'EXIF
  // (position, appareil), que l'encodeur réécrirait sinon tel quel.
  upright
    ..exif = img.ExifData()
    ..iccProfile = null
    ..textData = null;

  // Du plus grand côté permis (ou de celui de l'image, si elle est plus
  // petite : l'agrandir n'apporterait rien) jusqu'au plus petit lisible, par
  // paliers d'un quart ; à chaque palier, trois qualités.
  final largest = math.max(upright.width, upright.height);
  final floor = math.min(_smallestSide, largest);
  for (
    var side = math.min(maxSide, largest);
    side >= floor;
    side = side * 3 ~/ 4
  ) {
    final fitted = _fit(upright, side);
    for (final q in [quality, quality - 15, quality - 30]) {
      final jpeg = img.encodeJpg(fitted, quality: q);
      if (jpeg.lengthInBytes <= maxBytes) {
        return jpeg;
      }
    }
  }
  throw const MealPhotoException(MealPhotoFailure.tooLarge);
}

/// Sous ce côté, une photo de plat ne se reconnaît plus : on renonce plutôt
/// que d'envoyer une vignette illisible.
const int _smallestSide = 256;

/// Réduit pour que le plus grand côté tienne dans [side] ; ne grandit
/// jamais une petite image.
img.Image _fit(img.Image image, int side) {
  final largest = image.width > image.height ? image.width : image.height;
  if (largest <= side) {
    return image;
  }
  final landscape = image.width >= image.height;
  return img.copyResize(
    image,
    width: landscape ? side : null,
    height: landscape ? null : side,
    // La MOYENNE des pixels couverts : pour une forte réduction, les autres
    // interpolations ne lisent qu'un pixel sur plusieurs et crénellent.
    interpolation: img.Interpolation.average,
  );
}

/// Une image TRANSPARENTE (une capture PNG) posée sur du blanc : le JPEG n'a
/// pas de transparence, et ses pixels transparents deviendraient noirs.
img.Image _flatten(img.Image image) {
  if (!image.hasAlpha) {
    return image;
  }
  final background = img.Image(width: image.width, height: image.height)
    ..clear(img.ColorRgb8(255, 255, 255));
  return img.compositeImage(background, image);
}
