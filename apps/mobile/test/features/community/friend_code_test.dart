import 'package:carlys_mobile/features/community/domain/friend_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeFriendCode', () {
    test('toutes les formes humaines mènent à la même canonique', () {
      expect(normalizeFriendCode('AC23-DEF4'), 'AC23DEF4');
      expect(normalizeFriendCode('ac23def4'), 'AC23DEF4');
      expect(normalizeFriendCode('  AC23 DEF4 '), 'AC23DEF4');
      expect(normalizeFriendCode('carlys:friend:AC23DEF4'), 'AC23DEF4');
      expect(normalizeFriendCode('carlys:friend:ac23-def4'), 'AC23DEF4');
    });

    test('refuse ce qui n’est pas un code', () {
      expect(normalizeFriendCode(''), isNull);
      expect(normalizeFriendCode('AC23DEF'), isNull); // trop court
      expect(normalizeFriendCode('AC23DEF45'), isNull); // trop long
      expect(normalizeFriendCode('AC23DEF0'), isNull); // 0 hors alphabet
      expect(normalizeFriendCode('AC23DEFO'), isNull); // O hors alphabet
      expect(normalizeFriendCode('autre:qr:AC23DEF4'), isNull);
      expect(normalizeFriendCode('ami@exemple.fr'), isNull);
    });

    test('l’alphabet ne contient aucun caractère confondable', () {
      for (final banned in '01BGILOQSZ'.split('')) {
        expect(friendCodeAlphabet.contains(banned), isFalse, reason: banned);
      }
    });
  });

  test('la forme affichée XXXX-XXXX se re-normalise à l’identique', () {
    expect(formatFriendCode('AC23DEF4'), 'AC23-DEF4');
    expect(normalizeFriendCode(formatFriendCode('AC23DEF4')), 'AC23DEF4');
  });

  test('le QR porte le préfixe Carlys et se re-normalise', () {
    expect(friendCodeQrPayload('AC23DEF4'), 'carlys:friend:AC23DEF4');
    expect(normalizeFriendCode(friendCodeQrPayload('AC23DEF4')), 'AC23DEF4');
  });

  test('l’arobase départage e-mail et code dans le champ unique', () {
    expect(looksLikeEmail('ami@exemple.fr'), isTrue);
    expect(looksLikeEmail('AC23-DEF4'), isFalse);
  });
}
