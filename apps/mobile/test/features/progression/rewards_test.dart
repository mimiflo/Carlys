import 'package:carlys_mobile/features/progression/data/reward_ledger.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/reward_engine.dart';
import 'package:carlys_mobile/features/progression/domain/reward_facts_builder.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LES RÉCOMPENSES : la mémoire longue de Carlys.
///
/// La règle que ce fichier protège tient en une phrase : **ce qui est gagné
/// ne se reprend pas**. Le profil dérivé redescend après une interruption,
/// c'est voulu et c'est honnête ; les récompenses, elles, sont l'histoire de
/// la personne, et une histoire ne se réécrit pas parce qu'on a été malade
/// trois semaines.
void main() {
  WorkoutHistoryEntry session(DateTime day, {double volume = 1000}) {
    return WorkoutHistoryEntry(
      session: WorkoutInfo(
        id: 'seance-${day.toIso8601String()}',
        startedAt: day,
        status: WorkoutStatus.completed,
        syncState: LocalSyncState.synced,
      ),
      totalVolumeKg: volume,
      setsCount: 12,
    );
  }

  group('faits de récompense', () {
    test('la meilleure série de semaines est un RECORD, pas la série en cours',
        () {
      // Une série cassée reste gagnée : c'est exactement ce qui distingue
      // une récompense d'un score. Trois semaines de suite, un trou, puis
      // une reprise — le record vaut trois, pas un.
      final start = DateTime(2026, 1, 5);
      final facts = buildRewardFacts(
        history: [
          session(start),
          session(start.add(const Duration(days: 7))),
          session(start.add(const Duration(days: 14))),
          // Trou de deux semaines, puis reprise.
          session(start.add(const Duration(days: 35))),
        ],
        reachedTitle: CarlysTitle.apprenti,
      );

      expect(facts.bestWeekStreak, 3);
      expect(facts.completedSessions, 4);
    });

    test('les séances abandonnées ne comptent pas dans les caps', () {
      final abandoned = WorkoutHistoryEntry(
        session: WorkoutInfo(
          id: 'abandonnee',
          startedAt: DateTime(2026, 2, 3),
          status: WorkoutStatus.abandoned,
          syncState: LocalSyncState.synced,
        ),
        totalVolumeKg: 500,
        setsCount: 4,
      );

      final facts = buildRewardFacts(
        history: [abandoned],
        reachedTitle: CarlysTitle.apprenti,
      );

      expect(facts.completedSessions, 0);
      expect(facts.bestWeekStreak, 0);
    });

    test('les semaines à bon rythme se comptent entre deux et quatre séances',
        () {
      final monday = DateTime(2026, 3, 2);
      final facts = buildRewardFacts(
        history: [
          // Semaine à 3 séances : dans la fourchette.
          session(monday),
          session(monday.add(const Duration(days: 2))),
          session(monday.add(const Duration(days: 4))),
          // Semaine à 1 séance : trop peu pour progresser.
          session(monday.add(const Duration(days: 7))),
          // Semaine à 6 séances : trop pour récupérer.
          for (var day = 14; day < 20; day++)
            session(monday.add(Duration(days: day))),
        ],
        reachedTitle: CarlysTitle.apprenti,
      );

      expect(facts.balancedWeeks, 1);
    });
  });

  group('catalogue', () {
    RewardFacts factsWith({
      int sessions = 0,
      int streak = 0,
      int lessons = 0,
      int records = 0,
      CarlysTitle title = CarlysTitle.apprenti,
    }) =>
        RewardFacts(
          reachedTitle: title,
          completedSessions: sessions,
          bestWeekStreak: streak,
          lessonsAnswered: lessons,
          lessonsTotal: 22,
          personalRecords: records,
        );

    test('les seuils s’ouvrent dans l’ordre, jamais à l’envers', () {
      final ten = earnedRewards(factsWith(sessions: 10)).map((r) => r.id);
      expect(ten, contains('discipline-10'));
      expect(ten, isNot(contains('discipline-50')));

      final fifty = earnedRewards(factsWith(sessions: 50)).map((r) => r.id);
      expect(fifty, containsAll(['discipline-10', 'discipline-50']));
    });

    test('un pack d’Academy vide n’accorde PAS le certificat', () {
      // Zéro leçon sur zéro leçon vaut « tout fait » en arithmétique, et
      // c'est faux : le pack n'est simplement pas chargé.
      const empty = RewardFacts(
        reachedTitle: CarlysTitle.apprenti,
        lessonsAnswered: 0,
        lessonsTotal: 0,
      );

      expect(
        earnedRewards(empty).map((r) => r.id),
        isNot(contains('maitrise-pack')),
      );
    });

    test('les titres atteints sont des récompenses, cumulées', () {
      final ids =
          earnedRewards(factsWith(title: CarlysTitle.artisan)).map((r) => r.id);

      // Tous les titres franchis, pas seulement le dernier.
      expect(ids, containsAll(['titre-architecte', 'titre-artisan']));
      expect(ids, isNot(contains('titre-maitre')));
      // « Apprenti » n'est pas une récompense : c'est le point de départ.
      expect(ids, isNot(contains('titre-apprenti')));
    });

    test('ce qui vient est proposé UNE fois par axe, jamais trois paliers', () {
      final next = nextRewards(factsWith());

      expect(next, isNotEmpty);
      final values = next.map((reward) => reward.value).toList();
      expect(values.toSet().length, values.length);
    });
  });

  group('journal', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('une récompense obtenue ne se reprend JAMAIS', () async {
      // LE test de la marque. On gagne un cap, on s'arrête, les faits
      // redescendent : la médaille reste au journal.
      const ledger = RewardLedger();
      final day = DateTime(2026, 5, 1);

      await ledger.record(['constance-4'], day);
      final journal = await ledger.read();

      expect(journal['constance-4'], day);
      // La dérivation d'aujourd'hui n'accorde plus rien...
      expect(
        earnedRewards(const RewardFacts(reachedTitle: CarlysTitle.apprenti)),
        isEmpty,
      );
      // ...et le journal n'a pourtant rien perdu.
      expect((await ledger.read()).keys, contains('constance-4'));
    });

    test('la date de PREMIÈRE obtention ne se réécrit pas', () async {
      const ledger = RewardLedger();
      final first = DateTime(2026, 5, 1);

      await ledger.record(['discipline-10'], first);
      await ledger.record(['discipline-10'], DateTime(2026, 9, 30));

      expect((await ledger.read())['discipline-10'], first);
    });

    test('seules les récompenses NOUVELLES sont annoncées', () async {
      // C'est ce qui décide de la gravure : une gravure qui rejouerait à
      // chaque ouverture ne célébrerait plus rien.
      const ledger = RewardLedger();
      final day = DateTime(2026, 5, 1);

      final first = await ledger.record(['maitrise-5', 'discipline-10'], day);
      final second = await ledger.record(
        ['maitrise-5', 'discipline-10', 'constance-2'],
        day,
      );

      expect(first, {'maitrise-5', 'discipline-10'});
      expect(second, {'constance-2'});
    });

    test('un journal abîmé ne fait pas échouer l’écran', () async {
      SharedPreferences.setMockInitialValues({
        RewardLedger.key: 'ceci n’est pas du JSON',
      });

      expect(await const RewardLedger().read(), isEmpty);
    });
  });
}
