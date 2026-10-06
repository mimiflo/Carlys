import 'dart:convert';

import 'package:carlys_mobile/core/auth/token_deadline.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un JWT lisible qui vit 15 min et expire à [exp] (heure du SERVEUR).
String jwt(DateTime exp) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final s = exp.millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'none'})}.${part({'sub': 'u1', 'iat': s - 900, 'exp': s})}.sig';
}

void main() {
  var now = DateTime(2026, 10, 6, 12);
  setUp(() => now = DateTime(2026, 10, 6, 12));
  TokenDeadline deadline() => TokenDeadline(now: () => now);

  test('horloge en avance de 13 min 59 : le jeton neuf n’est pas renouvelé '
      'à chaque requête', () {
    // Le serveur émet un jeton de 15 min ; l'appareil, en avance de 839 s,
    // lui croit 61 s à vivre. L'échéance compte en DURÉE DE VIE.
    final d = deadline();
    final neuf = jwt(now.add(const Duration(seconds: 61)));
    d.renewed(neuf);

    now = now.add(const Duration(minutes: 5));
    expect(d.due(neuf), isFalse);
    now = now.add(const Duration(minutes: 9, seconds: 1));
    expect(d.due(neuf), isTrue);
  });

  test(
    'un jeton retrouvé au trousseau, presque expiré : renouvelé d’avance',
    () {
      final d = deadline();
      expect(d.due(jwt(now.add(const Duration(seconds: 30)))), isTrue);
      expect(d.due(jwt(now.add(const Duration(minutes: 10)))), isFalse);
    },
  );

  test('après un échec : pas de nouvel essai d’avance pendant 30 s', () {
    final d = deadline();
    final vieux = jwt(now.subtract(const Duration(minutes: 1)));
    expect(d.due(vieux), isTrue);
    d.failed();
    expect(d.due(vieux), isFalse);
    now = now.add(const Duration(seconds: 31));
    expect(d.due(vieux), isTrue);
  });

  test('un jeton sans échéance lisible n’est jamais anticipé', () {
    expect(deadline().due('pas.un.jwt'), isFalse);
  });
}
