import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
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

  group('les compteurs de VIE ENTIÈRE viennent du serveur', () {
    // LE BUG QUE CE GROUPE FERME : l'historique local est plafonné à 60
    // séances au rapatriement (`WorkoutSessionDownloader`). Sur un compte à
    // 200 séances, un téléphone neuf en dérivait 60, ne re-méritait pas
    // `discipline-150`, et la récompense DISPARAISSAIT — alors que le
    // journal promet qu'une médaille gagnée le reste.
    LifetimeStats vieEntiere(int semaines, int parSemaine) => LifetimeStats(
      completedSessions: semaines * parSemaine,
      weeks: [
        for (var index = 0; index < semaines; index++)
          LifetimeWeek(
            // Lundis consécutifs à partir du 5 janvier 2026.
            mondayOn: DateTime.utc(
              2026,
              1,
              5,
            ).add(Duration(days: index * 7)).toIso8601String().substring(0, 10),
            sessions: parSemaine,
          ),
      ],
    );

    test('le serveur l’emporte sur les 60 séances rapatriées', () {
      final facts = buildRewardFacts(
        // Ce qu'un téléphone NEUF voit : les soixante dernières séances.
        history: [
          for (var index = 0; index < 60; index++)
            session(DateTime(2026, 1, 5).add(Duration(days: index * 2))),
        ],
        reachedTitle: CarlysTitle.apprenti,
        lifetime: vieEntiere(70, 3),
      );

      expect(facts.completedSessions, 210);
      expect(facts.bestWeekStreak, 70);
      expect(facts.balancedWeeks, 70);
    });

    test('sans serveur, l’historique local reprend la main', () {
      // Hors ligne. Sous-compter n'efface rien : le journal ne s'écrit qu'en
      // AJOUT, et une récompense déjà inscrite y reste.
      final facts = buildRewardFacts(
        history: [
          session(DateTime(2026, 1, 5)),
          session(DateTime(2026, 1, 12)),
        ],
        reachedTitle: CarlysTitle.apprenti,
      );

      expect(facts.completedSessions, 2);
      expect(facts.bestWeekStreak, 2);
    });

    test('un trou de semaine reste un trou, quelle que soit la source', () {
      // La RÈGLE ne change pas de camp : le serveur sert des faits, le
      // moteur décide. Deux semaines, un trou, deux semaines — le record
      // vaut deux, pas quatre.
      final facts = buildRewardFacts(
        history: const [],
        reachedTitle: CarlysTitle.apprenti,
        lifetime: LifetimeStats(
          completedSessions: 12,
          weeks: const [
            LifetimeWeek(mondayOn: '2026-01-05', sessions: 3),
            LifetimeWeek(mondayOn: '2026-01-12', sessions: 3),
            LifetimeWeek(mondayOn: '2026-01-26', sessions: 3),
            LifetimeWeek(mondayOn: '2026-02-02', sessions: 3),
          ],
        ),
      );

      expect(facts.bestWeekStreak, 2);
      expect(facts.completedSessions, 12);
    });

    test(
      'une semaine hors du rythme tenable ne compte pas comme équilibrée',
      () {
        final facts = buildRewardFacts(
          history: const [],
          reachedTitle: CarlysTitle.apprenti,
          lifetime: LifetimeStats(
            completedSessions: 9,
            weeks: const [
              LifetimeWeek(mondayOn: '2026-01-05', sessions: 1), // trop peu
              LifetimeWeek(mondayOn: '2026-01-12', sessions: 3), // tenable
              LifetimeWeek(mondayOn: '2026-01-19', sessions: 5), // trop
            ],
          ),
        );

        expect(facts.balancedWeeks, 1);
      },
    );
  });

  group('faits de récompense', () {
    test(
      'la meilleure série de semaines est un RECORD, pas la série en cours',
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
      },
    );

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

    test(
      'les semaines à bon rythme se comptent entre deux et quatre séances',
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
      },
    );
  });

  group('catalogue', () {
    RewardFacts factsWith({
      int sessions = 0,
      int streak = 0,
      int lessons = 0,
      int records = 0,
      CarlysTitle title = CarlysTitle.apprenti,
    }) => RewardFacts(
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
      final ids = earnedRewards(
        factsWith(title: CarlysTitle.artisan),
      ).map((r) => r.id);

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
      final ledger = RewardLedger();
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
      final ledger = RewardLedger();
      final first = DateTime(2026, 5, 1);

      await ledger.record(['discipline-10'], first);
      await ledger.record(['discipline-10'], DateTime(2026, 9, 30));

      expect((await ledger.read())['discipline-10'], first);
    });

    test('seules les récompenses NOUVELLES sont annoncées', () async {
      // C'est ce qui décide de la gravure : une gravure qui rejouerait à
      // chaque ouverture ne célébrerait plus rien.
      final ledger = RewardLedger();
      final day = DateTime(2026, 5, 1);

      final first = await ledger.record(['maitrise-5', 'discipline-10'], day);
      final second = await ledger.record([
        'maitrise-5',
        'discipline-10',
        'constance-2',
      ], day);

      expect(first, {'maitrise-5', 'discipline-10'});
      expect(second, {'constance-2'});
    });

    test('la PREMIÈRE lecture ouvre le journal sans rien célébrer', () async {
      // Un compte qui s'entraîne depuis des mois mérite quinze récompenses
      // d'un coup à la première ouverture. Les graver ensemble ne
      // célébrerait rien : c'est une histoire qu'on inscrit, pas un cap
      // qu'on franchit.
      final ledger = RewardLedger();

      expect(await ledger.hasStarted(), isFalse);
      await ledger.start();
      expect(await ledger.hasStarted(), isTrue);

      // Et le journal ouvert reste lisible, simplement vide.
      expect(await ledger.read(), isEmpty);
    });

    test(
      'après l’ouverture, la récompense suivante est bien NOUVELLE',
      () async {
        final ledger = RewardLedger();
        await ledger.start();

        final fresh = await ledger.record([
          'constance-2',
        ], DateTime(2026, 6, 1));

        expect(fresh, {'constance-2'});
        expect(await ledger.hasStarted(), isTrue);
      },
    );

    test('un journal abîmé ne fait pas échouer l’écran', () async {
      SharedPreferences.setMockInitialValues({
        RewardLedger.key: 'ceci n’est pas du JSON',
      });

      expect(await RewardLedger().read(), isEmpty);
    });
  });
}
