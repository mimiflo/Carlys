import 'package:carlys_mobile/features/coaching/domain/services/coach_greeting.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le bonjour du coach à l'ouverture : écrit par l'appli, à la voix du
/// Mentor, sans jamais appeler le modèle.
void main() {
  final matin = DateTime(2026, 10, 1, 9, 30);
  final soir = DateTime(2026, 10, 1, 21);

  String greet({
    String? name = 'Florian Mottet',
    MentorStyle? style,
    bool returning = false,
    DateTime? now,
  }) => coachGreeting(
    displayName: name,
    style: style,
    returning: returning,
    now: now ?? matin,
  );

  test('dit bonjour le jour, bonsoir le soir, au prénom seul', () {
    expect(greet(), startsWith('Bonjour Florian !'));
    expect(greet(now: soir), startsWith('Bonsoir Florian !'));
    expect(greet(now: DateTime(2026, 10, 1, 3)), startsWith('Bonsoir'));
    expect(greet(now: DateTime(2026, 10, 1, 5)), startsWith('Bonjour'));
  });

  test('sans prénom, il salue quand même, sans trou ni espace en trop', () {
    expect(greet(name: null), startsWith('Bonjour !'));
    expect(greet(name: '   '), startsWith('Bonjour !'));
  });

  test('à la première visite il se présente ; au retour il reprend', () {
    expect(greet(), contains('Je suis ton coach'));
    expect(greet(returning: true), isNot(contains('Je suis ton coach')));
    expect(greet(returning: true), isNot(equals(greet())));
  });

  test('chaque voix du Mentor a sa phrase, et la voix neutre la sienne', () {
    for (final returning in [false, true]) {
      final phrases = {
        for (final style in [null, ...MentorStyle.values])
          greet(style: style, returning: returning),
      };
      expect(phrases, hasLength(MentorStyle.values.length + 1));
    }
  });

  test('du texte brut, sans tiret long, comme le coach lui-même', () {
    for (final style in [null, ...MentorStyle.values]) {
      for (final returning in [false, true]) {
        final text = greet(style: style, returning: returning);
        expect(text, isNot(contains('—')));
        expect(text, isNot(contains('*')));
      }
    }
  });
}
