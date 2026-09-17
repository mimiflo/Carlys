import 'package:carlys_mobile/features/mentor/domain/entities/mentor_prefs.dart';
import 'package:carlys_mobile/features/mentor/domain/entities/mentor_style.dart';
import 'package:carlys_mobile/features/mentor/domain/mentor_word.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le mot du Mentor : quatre voix qui disent VRAIMENT autre chose, une
/// rotation déterministe, et la célébration qui prend la parole.
void main() {
  final recompense = EarnedReward(
    reward: const Reward(
      id: 'maitrise-5',
      label: 'Cinq leçons abordées',
      story: 'Cinq questions abordées dans l’Academy.',
      kind: RewardKind.medaille,
    ),
    earnedAt: DateTime.utc(2026, 9, 16),
    isNew: true,
  );

  group('le catalogue des mots', () {
    test('chaque voix a les siens, et la voix neutre existe', () {
      expect(mentorWordCatalog.keys, containsAll(MentorStyle.values));
      expect(mentorWordCatalog[null], isNotEmpty);
      for (final mots in mentorWordCatalog.values) {
        expect(mots, isNotEmpty);
        for (final mot in mots) {
          expect(mot.trim(), isNotEmpty);
        }
      }
    });

    test('aucun mot n’est partagé entre deux voix : le contenu change', () {
      final tous = mentorWordCatalog.values.expand((mots) => mots).toList();
      expect(
        tous.toSet().length,
        tous.length,
        reason: 'Deux voix qui disent la même phrase ne sont qu’une voix.',
      );
    });
  });

  group('la rotation', () {
    test('au cran quotidien, le mot change d’un jour à l’autre', () {
      final lundi = mentorWord(
        style: MentorStyle.exigeant,
        frequence: MentorFrequency.quotidienne,
        now: DateTime(2026, 9, 14),
      );
      final mardi = mentorWord(
        style: MentorStyle.exigeant,
        frequence: MentorFrequency.quotidienne,
        now: DateTime(2026, 9, 15),
      );
      expect(lundi.message, isNot(mardi.message));
    });

    test('au cran hebdomadaire, le mot tient la semaine puis change', () {
      MentorWord auJour(int jour) => mentorWord(
        style: MentorStyle.philosophe,
        frequence: MentorFrequency.hebdomadaire,
        // Une semaine alignée sur le découpage jour-de-l'année ÷ 7.
        now: DateTime(2026, 1, jour),
      );

      expect(auJour(1).message, auJour(7).message);
      expect(auJour(1).message, isNot(auJour(8).message));
    });

    test(
      'sans style choisi, la voix neutre parle : jamais un style deviné',
      () {
        final mot = mentorWord(
          style: null,
          frequence: MentorFrequency.hebdomadaire,
          now: DateTime(2026, 9, 16),
        );
        expect(mentorWordCatalog[null], contains(mot.message));
        expect(mot.estCelebration, isFalse);
      },
    );
  });

  group('la célébration', () {
    test('prend la parole et emporte l’identifiant de la récompense', () {
      final mot = mentorWord(
        style: MentorStyle.athlete,
        frequence: MentorFrequency.hebdomadaire,
        now: DateTime(2026, 9, 16),
        aFeter: recompense,
      );

      expect(mot.estCelebration, isTrue);
      expect(mot.celebratedRewardId, 'maitrise-5');
      expect(mot.message, contains('Cinq leçons abordées'));
    });

    test('chaque voix fête à SA façon, la neutre comprise', () {
      final messages = [
        for (final style in [...MentorStyle.values, null])
          mentorWord(
            style: style,
            frequence: MentorFrequency.hebdomadaire,
            now: DateTime(2026, 9, 16),
            aFeter: recompense,
          ).message,
      ];
      expect(messages.toSet().length, messages.length);
    });
  });
}
