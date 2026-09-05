import 'package:carlys_mobile/features/dashboard/domain/entities/consistency_week.dart';
import 'package:flutter_test/flutter_test.dart';

/// Règle de la série de constance.
///
/// Principe directeur : la série encourage, elle ne punit pas. La journée en
/// cours ne la casse jamais, et les jours à venir ne sont pas des échecs.
void main() {
  // Mercredi 12 août 2026.
  final wednesday = DateTime(2026, 8, 12);
  DateTime day(int dayOfMonth) => DateTime(2026, 8, dayOfMonth);

  test('les sept jours partent du lundi et portent les bonnes initiales', () {
    final week = buildConsistencyWeek(trainedDays: {}, today: wednesday);

    expect(week.days.map((d) => d.initial), [
      'L',
      'M',
      'M',
      'J',
      'V',
      'S',
      'D',
    ]);
    expect(week.days.first.date, day(10)); // lundi
    expect(week.days.last.date, day(16)); // dimanche
  });

  test('aujourd’hui est marqué, les jours suivants sont « à venir »', () {
    final week = buildConsistencyWeek(trainedDays: {}, today: wednesday);

    expect(week.days[2].isToday, isTrue);
    expect(week.days.where((d) => d.isToday), hasLength(1));
    // Lundi et mardi sont passés — pas « à venir », même sans séance.
    expect(week.days.take(3).every((d) => !d.isFuture), isTrue);
    expect(week.days.skip(3).every((d) => d.isFuture), isTrue);
  });

  test('une flamme par jour réellement tenu', () {
    final week = buildConsistencyWeek(
      trainedDays: {day(10), day(12)},
      today: wednesday,
    );

    expect(week.days.map((d) => d.trained), [
      true, // lundi
      false,
      true, // mercredi
      false,
      false,
      false,
      false,
    ]);
    expect(week.trainedCount, 2);
  });

  test('la série compte les jours consécutifs à rebours', () {
    final week = buildConsistencyWeek(
      trainedDays: {day(10), day(11), day(12)},
      today: wednesday,
    );

    expect(week.streakDays, 3);
  });

  test('la journée en cours ne casse PAS la série : on repart d’hier', () {
    // Rien fait aujourd'hui, mais lundi et mardi tenus.
    final week = buildConsistencyWeek(
      trainedDays: {day(10), day(11)},
      today: wednesday,
    );

    expect(week.days[2].trained, isFalse);
    expect(week.streakDays, 2); // la série tient encore
  });

  test('deux jours sans séance rompent la série', () {
    final week = buildConsistencyWeek(
      trainedDays: {day(9), day(10)},
      today: wednesday,
    );

    expect(week.streakDays, 0);
  });

  test('aucune séance : série à zéro, aucun jour tenu', () {
    final week = buildConsistencyWeek(trainedDays: {}, today: wednesday);

    expect(week.streakDays, 0);
    expect(week.trainedCount, 0);
  });

  test('la série traverse les mois et les années', () {
    final newYear = DateTime(2027);
    final week = buildConsistencyWeek(
      trainedDays: {DateTime(2026, 12, 30), DateTime(2026, 12, 31), newYear},
      today: newYear,
    );

    expect(week.streakDays, 3);
  });

  test('un jour tenu hors de la semaine courante n’allume aucun rond', () {
    final week = buildConsistencyWeek(
      trainedDays: {day(3)}, // lundi précédent
      today: wednesday,
    );

    expect(week.trainedCount, 0);
  });
}
