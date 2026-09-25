import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:carlys_mobile/features/nutrition/data/services/meal_photo_preparation.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/meal_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// LA PRÉPARATION D'UNE PHOTO, sur de VRAIS octets.
///
/// La photo de référence, `test/fixtures/meal_photo/orientation_6_gps.jpg`
/// (875 octets), est écrite par Pillow (libjpeg), un AUTRE encodeur que
/// celui de l'application — comme le serait celle d'un téléphone : 64 × 32
/// pixels COUCHÉS, moitié gauche rouge, moitié droite bleue, avec l'étiquette
/// EXIF « orientation 6 » (tourner de 90° dans le sens horaire pour
/// afficher), une position GPS (48°51′24″ N, 2°21′3″ E), la marque
/// « CarlysTest » et le modèle « Fixture ». Recette, pour la refaire :
///
/// ```python
/// img = Image.new('RGB', (64, 32), (0, 0, 255))   # bleu…
/// # …sauf la moitié gauche, rouge (putpixel sur x < 32)
/// exif = Image.Exif(); exif[0x0112] = 6            # orientation
/// exif[0x010F] = 'CarlysTest'; exif[0x0110] = 'Fixture'
/// gps = exif.get_ifd(0x8825); gps[1] = 'N'; gps[2] = (48, 51, 24) …
/// img.save('orientation_6_gps.jpg', quality=95, exif=exif.tobytes())
/// ```
///
/// Ce que ce fichier protège : une photo prise téléphone debout sort DROITE
/// (le serveur retire l'étiquette avec les autres métadonnées : sans ce
/// redressement, le plat s'afficherait couché), et rien de ce que le
/// téléphone a inscrit dans l'image ne part.
void main() {
  final original = File(
    'test/fixtures/meal_photo/orientation_6_gps.jpg',
  ).readAsBytesSync();

  bool isRed(img.Pixel p) => p.r > 180 && p.g < 80 && p.b < 80;
  bool isBlue(img.Pixel p) => p.b > 180 && p.r < 80 && p.g < 80;

  /// [needle] figure-t-il, tel quel, dans [haystack] ?
  bool contains(Uint8List haystack, List<int> needle) {
    for (var start = 0; start + needle.length <= haystack.length; start++) {
      var match = true;
      for (var i = 0; i < needle.length; i++) {
        if (haystack[start + i] != needle[i]) {
          match = false;
          break;
        }
      }
      if (match) {
        return true;
      }
    }
    return false;
  }

  test('la photo de référence est bien couchée, étiquetée et localisée', () {
    // Sans ce témoin, un fichier refait sans EXIF ferait passer le reste
    // sans rien prouver. On lit le fichier TEL QU'IL EST : les dimensions
    // de la trame stockée et l'EXIF brut, sans rien décoder ni tourner.
    final frame = img.JpegDecoder().startDecode(original)!;
    expect((frame.width, frame.height), (64, 32));
    final exif = img.decodeJpgExif(original)!;
    expect(exif.imageIfd.orientation, 6);
    expect(exif.gpsIfd.isEmpty, isFalse);
    expect(contains(original, ascii.encode('CarlysTest')), isTrue);
  });

  test('une photo couchée (EXIF 6) sort DROITE : les pixels tournent', () {
    final prepared = prepareMealPhoto(original);

    // La TRAME stockée elle-même est debout : 64 × 32 couché → 32 × 64.
    // (Lue sans décoder : un décodeur qui appliquerait une étiquette
    // restante masquerait des pixels encore couchés.)
    final frame = img.JpegDecoder().startDecode(prepared)!;
    expect((frame.width, frame.height), (32, 64));
    // Et plus aucune étiquette : rien ne la tournerait une seconde fois.
    final exif = img.decodeJpgExif(prepared);
    expect(exif == null || !exif.imageIfd.hasOrientation, isTrue);
    // Un quart de tour horaire : la gauche (rouge) passe EN HAUT.
    final upright = img.decodeJpg(prepared)!;
    expect(isRed(upright.getPixel(16, 8)), isTrue);
    expect(isBlue(upright.getPixel(16, 56)), isTrue);
  });

  test('aucune métadonnée ne quitte le téléphone', () {
    final prepared = prepareMealPhoto(original);

    // Un JPEG (signature), sans segment EXIF ni rien de ce qu'il portait.
    expect(prepared.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    expect(img.decodeJpg(prepared)!.exif.isEmpty, isTrue);
    expect(contains(prepared, ascii.encode('Exif')), isFalse);
    expect(contains(prepared, ascii.encode('CarlysTest')), isFalse);
    expect(contains(prepared, ascii.encode('Fixture')), isFalse);
  });

  test('réduite à 1 600 px sur le plus grand côté, jamais agrandie', () {
    final large = img.encodeJpg(
      img.Image(width: 3200, height: 1800)..clear(img.ColorRgb8(90, 140, 60)),
    );
    final reduced = img.decodeJpg(prepareMealPhoto(large))!;
    expect((reduced.width, reduced.height), (1600, 900));

    final small = img.encodeJpg(
      img.Image(width: 300, height: 200)..clear(img.ColorRgb8(90, 140, 60)),
    );
    final kept = img.decodeJpg(prepareMealPhoto(small))!;
    expect((kept.width, kept.height), (300, 200));
  });

  test('sous la borne coûte que coûte : la qualité baisse, puis la taille', () {
    // Du bruit : le pire cas d'un JPEG, là où la compression ne gagne rien.
    final random = math.Random(42);
    final noise = img.Image(width: 900, height: 900);
    for (final pixel in noise) {
      pixel
        ..r = random.nextInt(256)
        ..g = random.nextInt(256)
        ..b = random.nextInt(256);
    }
    final source = img.encodeJpg(noise, quality: 95);
    const limit = 60 * 1024;
    expect(source.length, greaterThan(limit), reason: 'le cas est réel');

    final prepared = prepareMealPhoto(source, maxBytes: limit);

    expect(prepared.length, lessThanOrEqualTo(limit));
    expect(img.decodeJpg(prepared), isNotNull);
  });

  test('une capture transparente (PNG) est posée sur du blanc', () {
    final png = img.encodePng(
      img.Image(width: 20, height: 20, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 0)),
    );
    final flattened = img.decodeJpg(prepareMealPhoto(png))!;
    final pixel = flattened.getPixel(10, 10);
    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
    expect(pixel.b, greaterThan(240));
  });

  test(
    'des octets qui ne sont pas une image : « illisible », pas un plantage',
    () {
      expect(
        () =>
            prepareMealPhoto(Uint8List.fromList(utf8.encode('pas une image'))),
        throwsA(
          isA<MealPhotoException>().having(
            (e) => e.failure,
            'cause',
            MealPhotoFailure.unreadable,
          ),
        ),
      );
    },
  );
}
