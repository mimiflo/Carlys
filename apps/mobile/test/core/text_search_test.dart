import 'package:carlys_mobile/core/utilities/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chercher un prénom comme on le tape.
void main() {
  test('les accents et la casse ne comptent pas', () {
    expect(matchesSearch('Léa', 'lea'), isTrue);
    expect(matchesSearch('Éloïse', 'ELOISE'), isTrue);
    expect(matchesSearch('François', 'franc'), isTrue);
    expect(matchesSearch('Chloé', 'hlo'), isTrue);
  });

  test('les ligatures se déplient', () {
    expect(matchesSearch('Cœur', 'coeur'), isTrue);
  });

  test('une requête vide ou blanche retient tout', () {
    expect(matchesSearch('Mehdi', ''), isTrue);
    expect(matchesSearch('Mehdi', '   '), isTrue);
  });

  test('ce qui ne correspond pas est écarté', () {
    expect(matchesSearch('Sarah', 'léa'), isFalse);
  });
}
