import 'package:carlys_mobile/core/validators/form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateEmail', () {
    test('accepte une adresse valide (espaces tolérés)', () {
      expect(validateEmail('camille@example.com'), isNull);
      expect(validateEmail('  camille@example.com  '), isNull);
    });

    test('refuse le vide et les formats invalides', () {
      expect(validateEmail(null), isNotNull);
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('sans-arobase'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail('a b@c.fr'), isNotNull);
    });
  });

  group('validatePassword', () {
    test('exige la longueur minimale du contrat serveur', () {
      expect(validatePassword('court'), isNotNull);
      expect(validatePassword('a' * (passwordMinLength - 1)), isNotNull);
      expect(validatePassword('a' * passwordMinLength), isNull);
    });

    test('refuse au-delà de la longueur maximale', () {
      expect(validatePassword('a' * (passwordMaxLength + 1)), isNotNull);
    });
  });

  group('validateDisplayName', () {
    test('exige un nom non vide de 60 caractères maximum', () {
      expect(validateDisplayName(''), isNotNull);
      expect(validateDisplayName('   '), isNotNull);
      expect(validateDisplayName('Camille'), isNull);
      expect(validateDisplayName('a' * 61), isNotNull);
    });
  });
}
