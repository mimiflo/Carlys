import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const thin = '\u202F';

  group('formatThousands', () {
    test('sépare les milliers par une espace fine', () {
      expect(formatThousands(1840), '1${thin}840');
      expect(formatThousands(2410), '2${thin}410');
      expect(formatThousands(186), '186');
      expect(formatThousands(1000000), '1${thin}000${thin}000');
    });

    test('arrondit et garde le signe', () {
      expect(formatThousands(1839.6), '1${thin}840');
      expect(formatThousands(-1840), '-1${thin}840');
    });
  });

  group('formatDecimal', () {
    test('utilise la virgule et masque les décimales nulles', () {
      expect(formatDecimal(82.5), '82,5');
      expect(formatDecimal(80), '80');
      expect(formatDecimal(6.44), '6,4');
    });
  });

  group('formatVolume', () {
    test('bascule en tonnes au-delà de 1 000 kg', () {
      final heavy = formatVolume(6400);
      expect(heavy.value, '6,4');
      expect(heavy.unit, 't');
    });

    test('reste en kilogrammes en dessous', () {
      final light = formatVolume(840);
      expect(light.value, '840');
      expect(light.unit, 'kg');
    });
  });

  group('durées', () {
    test('formatDurationShort', () {
      expect(formatDurationShort(3240), '54 MIN');
      expect(formatDurationShort(3900), '1 H 05');
    });

    test('formatChrono', () {
      expect(formatChrono(1122), '18:42');
      expect(formatChrono(4722), '1:18:42');
      expect(formatChrono(-5), '00:00');
    });
  });

  group('dates', () {
    test('formats mono', () {
      final date = DateTime(2025, 11, 11);
      expect(formatShortDateMono(date), 'MAR. 11 NOV.');
      expect(formatLongDateMono(date), 'MARDI 11 NOV.');
      expect(formatMonthYearCapitalized(date), 'Novembre 2025');
      expect(formatMonthYear(date), 'novembre 2025');
      expect(formatMonthYearMono(DateTime(2025, 3, 4)), 'MARS 2025');
    });

    test('un instant UTC est rendu dans le JOUR LOCAL, pas le jour UTC', () {
      // Les instants viennent de l'API en UTC. Lire `date.day` brut affichait
      // le quantième ET le nom du jour de la date UTC : un encouragement du
      // vendredi soir à Montréal se lisait « sam. 5 sept. ».
      //
      // 23 h 30 UTC : dans tout fuseau à l'est de UTC (l'Europe, donc le
      // fuseau du dépôt) le jour LOCAL est déjà le lendemain, et c'est là que
      // la garde mord. Sous UTC même, les deux jours coïncident et le test
      // passe des deux façons — comme la garde du changement d'heure.
      final instantUtc = DateTime.utc(2026, 9, 4, 23, 30);
      expect(
        formatShortDateMono(instantUtc),
        formatShortDateMono(instantUtc.toLocal()),
      );
      // Et sur une date déjà locale, rien ne bouge.
      final locale = DateTime(2025, 11, 11);
      expect(formatShortDateMono(locale), 'MAR. 11 NOV.');
    });

    test('dates relatives', () {
      final now = DateTime(2025, 11, 15, 10);
      String relative(DateTime date) => formatRelativeDayMono(date, now: now);

      expect(relative(DateTime(2025, 11, 15)), 'AUJOURD’HUI');
      expect(relative(DateTime(2025, 11, 14)), 'HIER');
      expect(relative(DateTime(2025, 11, 11)), 'IL Y A 4 JOURS');
      expect(relative(DateTime(2025, 11, 4)), 'IL Y A 1 SEMAINE');
      expect(relative(DateTime(2025, 10, 25)), 'IL Y A 3 SEMAINES');
      expect(relative(DateTime(2025, 8, 15)), 'IL Y A 3 MOIS');
    });
  });

  group('jour nommé et heure', () {
    test('aujourd’hui, hier, puis la date', () {
      final now = DateTime(2026, 9, 23, 10);
      expect(formatSpokenDay(DateTime(2026, 9, 23, 8, 24), now), 'Aujourd’hui');
      expect(formatSpokenDay(DateTime(2026, 9, 22, 23, 59), now), 'Hier');
      expect(formatSpokenDay(DateTime(2026, 9, 12, 7), now), '12/09/2026');
      // Le 1er du mois : « hier » est la veille, même d'un autre mois.
      expect(
        formatSpokenDay(DateTime(2026, 8, 31, 20), DateTime(2026, 9, 1, 9)),
        'Hier',
      );
    });

    test('le jour et le mois, sans le jour de la semaine', () {
      expect(formatDayMonth(DateTime(2026, 9, 30, 12)), '30 sept.');
      expect(formatDayMonth(DateTime(2026, 5, 1, 12)), '1 mai');
    });

    test('l’heure en 24 h', () {
      expect(formatClock(DateTime(2026, 9, 23, 8, 4)), '08h04');
      expect(formatClock(DateTime(2026, 9, 23, 18, 30)), '18h30');
    });
  });
}
