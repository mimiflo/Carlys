import 'dart:io';

import 'package:path/path.dart' as p;

/// Les COPIES qu'`image_picker` laisse sur le disque de l'application, et
/// leur effacement.
///
/// Sous Android (`image_picker_android` 0.8.13), un choix dans la GALERIE
/// en fait deux, dans le cache de l'application :
///  1. l'ORIGINALE, copiée telle quelle, métadonnées et position GPS
///     comprises, dans `cache/<uuid>/<nom>` (`FileUtils.getPathFromUri`) ;
///  2. la copie RÉDUITE, `cache/scaled_<nom>`, dont le chemin est rendu.
///
/// Le greffon n'efface jamais la première : il ne compte que sur
/// `deleteOnExit`, qu'il sait lui-même peu fiable sous Android. La prise
/// par l'appareil photo, elle, efface son original une fois réduit ; iOS ne
/// fait qu'une copie, celle qui est rendue.
///
/// [discardPickerCopies] efface la copie rendue ([path]), puis, si
/// [sweepOriginals], les dossiers d'originaux voisins : au nom d'UUID et ne
/// contenant QUE des images — la signature exacte de ceux du greffon. Ceux
/// d'une prise précédente interrompue (application tuée entre la prise et
/// l'effacement) partent avec. Rien d'autre du cache n'est touché.
///
/// Un échec n'empêche pas la photo de partir : il est rendu à l'appelant
/// pour qu'il le journalise ([onFailure]).
Future<void> discardPickerCopies(
  String path, {
  required bool sweepOriginals,
  required void Function(FileSystemException error) onFailure,
}) async {
  final returned = File(path);
  await _delete(returned, onFailure);
  if (!sweepOriginals) {
    return;
  }
  final cache = _uuidName.hasMatch(p.basename(returned.parent.path))
      // Le greffon a rendu l'originale elle-même (rien à réduire) : son
      // dossier est dans le cache, un cran plus haut.
      ? returned.parent.parent
      : returned.parent;
  try {
    await for (final entry in cache.list(followLinks: false)) {
      if (entry is Directory &&
          _uuidName.hasMatch(p.basename(entry.path)) &&
          await _holdsOnlyImages(entry)) {
        await entry.delete(recursive: true);
      }
    }
  } on FileSystemException catch (error) {
    onFailure(error);
  }
}

Future<void> _delete(
  File file,
  void Function(FileSystemException) onFailure,
) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } on FileSystemException catch (error) {
    onFailure(error);
  }
}

/// Le dossier ne contient que des fichiers d'image (vide compris : le
/// greffon l'a créé, la copie a échoué ou vient d'être effacée).
Future<bool> _holdsOnlyImages(Directory directory) async {
  await for (final entry in directory.list(followLinks: false)) {
    if (entry is! File ||
        !_imageExtensions.contains(p.extension(entry.path).toLowerCase())) {
      return false;
    }
  }
  return true;
}

/// `UUID.randomUUID().toString()` : le nom des dossiers du greffon.
final RegExp _uuidName = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Les extensions que le greffon donne à une image (d'après son type MIME).
const Set<String> _imageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.heic',
  '.heif',
  '.webp',
  '.gif',
  '.bmp',
};
