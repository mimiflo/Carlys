import 'dart:io';

import 'package:carlys_mobile/features/nutrition/data/services/picker_copies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// LES COPIES DU GREFFON : sous Android, un choix dans la galerie laisse
/// l'ORIGINALE (position GPS comprise) dans `cache/<uuid>/<nom>`, à côté de
/// la copie réduite `cache/scaled_<nom>` qu'il rend. La politique de
/// confidentialité promet que la copie remise à l'application est effacée
/// dès que la photo est préparée : ces tests le tiennent, sur un vrai
/// disque (un dossier temporaire), sans greffon.
void main() {
  late Directory cache;

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('cache_');
  });

  tearDown(() async {
    if (await cache.exists()) {
      await cache.delete(recursive: true);
    }
  });

  File put(String relative) => File(p.join(cache.path, relative))
    ..createSync(recursive: true)
    ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

  bool exists(String relative) =>
      FileSystemEntity.typeSync(p.join(cache.path, relative)) !=
      FileSystemEntityType.notFound;

  const uuid = '1b4e28ba-2fa1-41d2-883f-0016d3cca427';
  const earlier = '6fa459ea-ee8a-4ca4-894e-db77e160355e';
  const foreign = '9b2c1e7a-4d3f-4b8e-a1c2-0f9e8d7c6b5a';

  test('galerie, Android : la copie rendue ET l’originale partent', () async {
    put('$uuid/IMG_2041.jpg');
    final scaled = put('scaled_IMG_2041.jpg');
    // Le reste d'une prise interrompue (application tuée entre la prise et
    // l'effacement) : une originale, elle aussi.
    put('$earlier/IMG_1999.heic');
    // Ce qui n'est pas au greffon reste : un dossier au nom quelconque, et
    // un dossier au nom d'UUID qui ne contient pas que des images.
    put('images_du_catalogue/squat.webp');
    put('$foreign/notes.txt');
    final failures = <FileSystemException>[];

    await discardPickerCopies(
      scaled.path,
      sweepOriginals: true,
      onFailure: failures.add,
    );

    expect(exists('scaled_IMG_2041.jpg'), isFalse);
    expect(exists(uuid), isFalse, reason: 'l’originale, GPS compris');
    expect(exists(earlier), isFalse);
    expect(exists('images_du_catalogue/squat.webp'), isTrue);
    expect(exists('$foreign/notes.txt'), isTrue);
    expect(failures, isEmpty);
  });

  test('l’originale rendue telle quelle (rien à réduire) : son dossier part '
      'avec elle', () async {
    final original = put('$uuid/IMG_2041.jpg');

    await discardPickerCopies(
      original.path,
      sweepOriginals: true,
      onFailure: (_) => fail('aucun échec attendu'),
    );

    expect(exists(uuid), isFalse);
    expect(await cache.exists(), isTrue, reason: 'le cache lui-même reste');
  });

  test('iOS : une seule copie, rendue, et rien d’autre n’est touché', () async {
    final returned = put('image_picker_0A1B.jpg');
    put('$uuid/autre.jpg');

    await discardPickerCopies(
      returned.path,
      sweepOriginals: false,
      onFailure: (_) => fail('aucun échec attendu'),
    );

    expect(exists('image_picker_0A1B.jpg'), isFalse);
    expect(exists('$uuid/autre.jpg'), isTrue);
  });

  test('une copie déjà partie n’est pas un échec', () async {
    final failures = <FileSystemException>[];

    await discardPickerCopies(
      p.join(cache.path, 'scaled_absente.jpg'),
      sweepOriginals: true,
      onFailure: failures.add,
    );

    expect(failures, isEmpty);
  });
}
