import 'package:carlys_mobile/features/nutrition/domain/height_cm.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la taille saisie localement obéit aux MÊMES
/// bornes que le serveur.
///
/// L'API refuse au-delà d'une décimale (`@IsNumber({ maxDecimalPlaces: 1 })`,
/// adossé à `HEIGHT_CM_DECIMALS` dans le contrat publié). L'écran, lui, ne
/// vérifiait que l'intervalle : « 175,25 » passait la validation locale pour
/// se faire refuser par le serveur, et le formulaire n'avait rien de plus
/// précis à dire qu'un message générique.
void main() {
  group('parse', () {
    test('lit la virgule française comme le point', () {
      expect(HeightCm.parse('175,5'), 175.5);
      expect(HeightCm.parse('175.5'), 175.5);
      expect(HeightCm.parse('  178  '), 178);
    });

    test('un champ vide ou illisible rend null', () {
      expect(HeightCm.parse(''), isNull);
      expect(HeightCm.parse('   '), isNull);
      expect(HeightCm.parse('grand'), isNull);
    });
  });

  group('format', () {
    test('omet la décimale quand elle est inutile', () {
      expect(HeightCm.format(178), '178');
    });

    test('écrit la décimale à la française', () {
      expect(HeightCm.format(175.5), '175,5');
    });
  });

  group('hasAllowedPrecision', () {
    test('accepte une décimale, refuse deux', () {
      expect(HeightCm.hasAllowedPrecision(175.5), isTrue);
      expect(HeightCm.hasAllowedPrecision(178), isTrue);
      expect(HeightCm.hasAllowedPrecision(175.25), isFalse);
    });

    test('les décimales non représentables en binaire restent acceptées', () {
      // 175.1 vaut en réalité 175.09999999999999432... : une comparaison
      // naïve de chaînes, ou une égalité stricte, refuserait cette saisie
      // parfaitement légitime. C'est le piège que la tolérance évite.
      expect(175.1.toString(), '175.1');
      expect(HeightCm.hasAllowedPrecision(175.1), isTrue);
      expect(HeightCm.hasAllowedPrecision(80.3), isTrue);
      expect(HeightCm.hasAllowedPrecision(249.7), isTrue);
    });
  });

  group('validationError', () {
    test('un champ vide convient : la taille est facultative', () {
      expect(HeightCm.validationError(null), isNull);
      expect(HeightCm.validationError('  '), isNull);
    });

    test('hors bornes : le message nomme l’intervalle', () {
      expect(HeightCm.validationError('60'), contains('80'));
      expect(HeightCm.validationError('300'), contains('250'));
      expect(HeightCm.validationError('grand'), contains('80'));
    });

    test('deux décimales : le message le DIT, au lieu d’un refus serveur', () {
      expect(HeightCm.validationError('175,25'), contains('décimale'));
    });

    test('une saisie correcte ne produit rien', () {
      expect(HeightCm.validationError('178'), isNull);
      expect(HeightCm.validationError('175,5'), isNull);
    });
  });
}
