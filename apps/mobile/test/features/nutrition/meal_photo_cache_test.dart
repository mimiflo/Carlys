import 'dart:typed_data';

import 'package:carlys_mobile/features/nutrition/data/repositories/meal_photo_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';

/// LE CACHE DES PHOTOS DE REPAS : par (repas, date de la photo), en mémoire,
/// borné par octets.
///
/// La date est la clé parce que l'adresse d'une photo ne change pas quand
/// on la remplace : c'est elle, et elle seule, qui dit « ce n'est plus la
/// même ».
void main() {
  final monday = DateTime.utc(2026, 9, 21, 12);
  final tuesday = DateTime.utc(2026, 9, 22, 12);

  Uint8List bytes(int length, [int fill = 1]) =>
      Uint8List.fromList(List.filled(length, fill));

  late FakeNutritionRepository nutrition;
  late MealPhotoCache cache;

  setUp(() {
    nutrition = FakeNutritionRepository()..photos['repas'] = bytes(4);
    cache = MealPhotoCache(nutrition);
  });

  test('une même photo ne se lit qu’une fois', () async {
    final first = await cache.read('repas', monday);
    final second = await cache.read('repas', monday);

    expect(second, same(first));
    expect(nutrition.photoReads, ['repas']);
  });

  test('deux demandes simultanées font UNE requête', () async {
    final both = await Future.wait([
      cache.read('repas', monday),
      cache.read('repas', monday),
    ]);

    expect(both.first, same(both.last));
    expect(nutrition.photoReads, ['repas']);
  });

  test('une photo REMPLACÉE (autre date) se relit', () async {
    await cache.read('repas', monday);
    nutrition.photos['repas'] = bytes(4, 2);

    final replaced = await cache.read('repas', tuesday);

    expect(replaced, bytes(4, 2));
    expect(nutrition.photoReads, ['repas', 'repas']);
  });

  test('la photo qu’on vient d’envoyer se range sans aller-retour', () async {
    final sent = bytes(5, 7);
    cache.remember('repas', tuesday, sent);

    expect(await cache.read('repas', tuesday), same(sent));
    expect(nutrition.photoReads, isEmpty);
  });

  test('oublier un repas efface toutes ses versions', () async {
    await cache.read('repas', monday);
    cache.forget('repas');
    expect(cache.bytes, 0);

    await cache.read('repas', monday);
    expect(nutrition.photoReads, ['repas', 'repas']);
  });

  test(
    'sans photo (404) : rien n’est gardé, la prochaine lecture redemande',
    () async {
      expect(await cache.read('inconnu', monday), isNull);
      expect(await cache.read('inconnu', monday), isNull);
      expect(nutrition.photoReads, ['inconnu', 'inconnu']);
    },
  );

  test(
    'le budget se tient en OCTETS : la plus anciennement vue part',
    () async {
      final small = MealPhotoCache(nutrition, budgetBytes: 10);
      nutrition.photos
        ..['a'] = bytes(6)
        ..['b'] = bytes(6);

      await small.read('a', monday);
      await small.read('b', monday);

      expect(small.bytes, 6, reason: '12 octets pour un budget de 10');
      await small.read('b', monday);
      expect(nutrition.photoReads, ['a', 'b'], reason: 'b est resté');
      await small.read('a', monday);
      expect(nutrition.photoReads, ['a', 'b', 'a'], reason: 'a était parti');
    },
  );
}
