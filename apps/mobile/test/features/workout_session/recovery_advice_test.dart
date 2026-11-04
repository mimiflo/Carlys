import 'package:carlys_mobile/features/workout_history/presentation/utils/recovery_sentence.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/perceived_effort.dart';
import 'package:carlys_mobile/features/workout_session/domain/services/recovery_advice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Un lundi, 18 h 00 locales.
  final endedAt = DateTime(2026, 11, 2, 18);

  group('recoveryAdvice — effort perçu → repos', () {
    test('rien sans effort choisi', () {
      expect(
        recoveryAdvice(
          perceivedEffort: null,
          endedAt: endedAt,
          muscleGroups: const ['Pectoraux'],
        ),
        isNull,
      );
    });

    test('rien sans fin de séance', () {
      expect(
        recoveryAdvice(
          perceivedEffort: 5,
          endedAt: null,
          muscleGroups: const ['Pectoraux'],
        ),
        isNull,
      );
    });

    test('≤ 4 : 24 h ; 5 ou 6 : 48 h ; ≥ 7 : 72 h', () {
      Duration restFor(int effort) => recoveryAdvice(
        perceivedEffort: effort,
        endedAt: endedAt,
        muscleGroups: const [],
      )!.rest;

      for (final effort in [1, 2, 3, 4]) {
        expect(restFor(effort), const Duration(hours: 24), reason: '$effort');
      }
      expect(restFor(5), const Duration(hours: 48));
      expect(restFor(6), const Duration(hours: 48));
      for (final effort in [7, 8, 9, 10]) {
        expect(restFor(effort), const Duration(hours: 72), reason: '$effort');
      }
    });

    test('compte depuis la fin de séance', () {
      final advice = recoveryAdvice(
        perceivedEffort: 5,
        endedAt: endedAt,
        muscleGroups: const [],
      )!;
      expect(advice.until, DateTime(2026, 11, 4, 18));
    });

    test('les groupes, sans doublon, dans l’ordre de la séance', () {
      final advice = recoveryAdvice(
        perceivedEffort: 5,
        endedAt: endedAt,
        muscleGroups: const ['Pectoraux', 'Triceps', 'pectoraux', 'Triceps'],
      )!;
      expect(advice.muscleGroups, ['Pectoraux', 'Triceps']);
    });
  });

  group('EffortChoice — les cinq réponses du bilan', () {
    test('chacune sur sa valeur de Borg', () {
      expect(
        {for (final c in EffortChoice.values) c.label: c.borg},
        {
          'Très facile': 2,
          'Facile': 4,
          'Modéré': 5,
          'Difficile': 7,
          'À fond': 9,
        },
      );
    });

    test('une valeur venue d’ailleurs retombe sur sa réponse', () {
      expect(EffortChoice.fromBorg(null), isNull);
      expect(EffortChoice.fromBorg(1), EffortChoice.veryEasy);
      expect(EffortChoice.fromBorg(3), EffortChoice.easy);
      expect(EffortChoice.fromBorg(6), EffortChoice.moderate);
      expect(EffortChoice.fromBorg(8), EffortChoice.hard);
      expect(EffortChoice.fromBorg(10), EffortChoice.allOut);
      for (final choice in EffortChoice.values) {
        expect(EffortChoice.fromBorg(choice.borg), choice);
      }
    });
  });

  group('recoverySentence — la phrase du bilan', () {
    RecoveryAdvice advice(List<String> muscles, {DateTime? end}) =>
        recoveryAdvice(
          perceivedEffort: 5,
          endedAt: end ?? endedAt,
          muscleGroups: muscles,
        )!;

    test('muscles et échéance locale', () {
      expect(
        recoverySentence(advice(const ['Pectoraux', 'Triceps']), now: endedAt),
        'Repos conseillé : 48 h pour pectoraux et triceps, jusqu’à mercredi 18 h',
      );
    });

    test('trois groupes et plus : virgules puis « et »', () {
      expect(
        recoverySentence(
          advice(const ['Pectoraux', 'Épaules', 'Triceps']),
          now: endedAt,
        ),
        'Repos conseillé : 48 h pour pectoraux, épaules et triceps, '
        'jusqu’à mercredi 18 h',
      );
    });

    test('sans muscles connus (hors ligne), la durée seule', () {
      expect(
        recoverySentence(advice(const []), now: endedAt),
        'Repos conseillé : 48 h, jusqu’à mercredi 18 h',
      );
    });

    test('une fin à 18 h 20 conseille jusqu’à 19 h, jamais avant', () {
      expect(
        recoverySentence(
          advice(const ['Dos'], end: DateTime(2026, 11, 2, 18, 20)),
          now: endedAt,
        ),
        'Repos conseillé : 48 h pour dos, jusqu’à mercredi 19 h',
      );
    });

    test('échéance passée (séance relue plus tard) : pas de date', () {
      expect(
        recoverySentence(advice(const ['Dos']), now: DateTime(2026, 11, 20)),
        'Repos conseillé : 48 h pour dos',
      );
    });

    test('l’heure affichée est LOCALE même pour une fin en UTC', () {
      final utc = endedAt.toUtc();
      final sentence = recoverySentence(advice(const [], end: utc), now: utc);
      expect(sentence, endsWith('mercredi 18 h'));
    });
  });
}
