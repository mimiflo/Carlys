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

    test('dates relatives', () {
      final now = DateTime(2025, 11, 15, 10);
      expect(formatRelativeDayMono(DateTime(2025, 11, 15), now: now),
          'AUJOURD’HUI');
      expect(formatRelativeDayMono(DateTime(2025, 11, 14), now: now), 'HIER');
      expect(formatRelativeDayMono(DateTime(2025, 11, 11), now: now),
          'IL Y A 4 JOURS');
      expect(formatRelativeDayMono(DateTime(2025, 11, 4), now: now),
          'IL Y A 1 SEMAINE');
      expect(formatRelativeDayMono(DateTime(2025, 10, 25), now: now),
          'IL Y A 3 SEMAINES');
      expect(
          formatRelativeDayMono(DateTime(2025, 8, 15), now: now), 'IL Y A 3 MOIS');
    });
  });
}
