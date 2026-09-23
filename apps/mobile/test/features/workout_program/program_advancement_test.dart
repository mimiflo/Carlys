import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/domain/program_advancement.dart';
import 'package:flutter_test/flutter_test.dart';

/// OÙ EN EST LE PROGRAMME : une position dans le plan, en jours civils.
///
/// Le profil affiche « 24 % du programme » : ce fichier fixe ce que ce
/// nombre veut dire, jour par jour, bornes comprises.
void main() {
  group('programAdvancement', () {
    ProgramAdvancement? at(DateTime today, {String? startsOn = '2026-09-07'}) =>
        programAdvancement(startsOn: startsOn, weeksCount: 4, today: today);

    test('sans premier jour, aucune position n’est inventée', () {
      expect(at(DateTime(2026, 9, 23), startsOn: null), isNull);
      expect(
        programAdvancement(
          startsOn: '2026-09-07',
          weeksCount: 0,
          today: DateTime(2026, 9, 23),
        ),
        isNull,
      );
    });

    test('le premier jour vaut 0 % : le jour en cours ne compte pas', () {
      final avancement = at(DateTime(2026, 9, 7, 21))!;
      expect(avancement.phase, ProgramPhase.running);
      expect(avancement.percent, 0);
      expect(avancement.weekNumber, 1);
    });

    test('au milieu : jours passés sur jours du plan, tronqué', () {
      // 16 jours passés sur 28 : 57,14… % s'affiche 57.
      final avancement = at(DateTime(2026, 9, 23, 8))!;
      expect(avancement.elapsedDays, 16);
      expect(avancement.totalDays, 28);
      expect(avancement.percent, 57);
      expect(avancement.weekNumber, 3);
    });

    test('la veille de la fin n’est pas 100 %', () {
      final avancement = at(DateTime(2026, 10, 4, 23, 59))!;
      expect(avancement.phase, ProgramPhase.running);
      expect(avancement.percent, 96);
      expect(avancement.weekNumber, 4);
    });

    test('le lendemain du dernier jour : fini, 100 %, dernière semaine', () {
      final avancement = at(DateTime(2026, 10, 5))!;
      expect(avancement.phase, ProgramPhase.finished);
      expect(avancement.percent, 100);
      expect(avancement.weekNumber, 4);

      // Et longtemps après : toujours borné, jamais 250 %.
      expect(at(DateTime(2027, 1, 1))!.percent, 100);
    });

    test('avant le départ : à venir, 0 %, le compte à rebours dit', () {
      final avancement = at(DateTime(2026, 9, 2))!;
      expect(avancement.phase, ProgramPhase.upcoming);
      expect(avancement.percent, 0);
      expect(avancement.weekNumber, 1);
      expect(avancement.daysUntilStart, 5);
    });

    test('un passage à l’heure d’hiver ne décale pas le compte', () {
      // Le 25 octobre 2026, la nuit dure 25 heures en Europe : compter en
      // tranches de 24 heures perdrait ou gagnerait un jour selon l'heure.
      final avancement = programAdvancement(
        startsOn: '2026-10-19',
        weeksCount: 2,
        today: DateTime(2026, 10, 26, 0, 30),
      )!;
      expect(avancement.elapsedDays, 7);
      expect(avancement.weekNumber, 2);
    });
  });

  group('programRhythm', () {
    ProgramDayEntry day(int week, int dayOfWeek, {bool isRest = false}) =>
        ProgramDayEntry(
          id: 'j-$week-$dayOfWeek',
          weekNumber: week,
          dayOfWeek: dayOfWeek,
          label: isRest ? 'Repos' : 'Séance',
          isRest: isRest,
        );

    ProgramDetail plan(int weeks, List<ProgramDayEntry> days) => ProgramDetail(
      id: 'p',
      name: 'Plan',
      weeksCount: weeks,
      isActive: true,
      days: days,
    );

    test('semaines égales : le rythme se dit par semaine, repos exclus', () {
      final rythme = programRhythm(
        plan(2, [
          for (final week in [1, 2]) ...[
            day(week, 1),
            day(week, 2, isRest: true),
            day(week, 3),
            day(week, 5),
          ],
        ]),
      );
      expect(rythme.sessionsPerWeek, 3);
      expect(rythme.total, 6);
    });

    test('semaines inégales : aucune moyenne, seulement le total', () {
      final rythme = programRhythm(plan(2, [day(1, 1), day(1, 3), day(2, 1)]));
      expect(rythme.sessionsPerWeek, isNull);
      expect(rythme.total, 3);
    });

    test('une semaine vide compte : 3 puis 0 n’est pas « 3 par semaine »', () {
      final rythme = programRhythm(plan(2, [day(1, 1), day(1, 3), day(1, 5)]));
      expect(rythme.sessionsPerWeek, isNull);
      expect(rythme.total, 3);
    });

    test('un jour hors du plan est ignoré plutôt que de faire planter', () {
      final rythme = programRhythm(plan(1, [day(1, 1), day(3, 1)]));
      expect(rythme.sessionsPerWeek, 1);
      expect(rythme.total, 1);
    });
  });
}
