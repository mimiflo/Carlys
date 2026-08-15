import 'package:carlys_mobile/features/dashboard/data/daily_quotes.dart';
import 'package:carlys_mobile/features/dashboard/domain/entities/daily_quote.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le recueil et sa rotation.
///
/// Deux garanties tiennent la fonctionnalité : la maxime ne change pas dans
/// la journée, et deux jours de suite ne servent jamais la même valeur.
void main() {
  test('la maxime ne bouge pas au fil de la journée', () {
    final morning = DateTime(2026, 8, 12, 6, 30);
    final night = DateTime(2026, 8, 12, 23, 59);

    expect(quoteOfTheDay(morning).text, quoteOfTheDay(night).text);
  });

  test('elle change chaque jour', () {
    final today = quoteOfTheDay(DateTime(2026, 8, 12));
    final tomorrow = quoteOfTheDay(DateTime(2026, 8, 13));

    expect(today.text, isNot(tomorrow.text));
  });

  test('deux jours consécutifs ne servent jamais la même valeur', () {
    var previous = quoteOfTheDay(DateTime(2026)).value;
    for (var offset = 1; offset <= 400; offset++) {
      final value = quoteOfTheDay(DateTime(2026, 1, 1 + offset)).value;
      expect(value, isNot(previous), reason: 'jour $offset');
      previous = value;
    }
  });

  test('le recueil tourne sans jamais sortir de ses bornes', () {
    // Deux tours complets, en arrière comme en avant.
    for (var offset = -80; offset <= 80; offset++) {
      final quote = quoteOfTheDay(DateTime(2026, 8, 12 + offset));
      expect(carlysQuotes, contains(quote));
    }
  });

  test('les cinq valeurs sont représentées à parts égales', () {
    final counts = <CarlysValue, int>{};
    for (final quote in carlysQuotes) {
      counts[quote.value] = (counts[quote.value] ?? 0) + 1;
    }

    expect(counts.keys.toSet(), CarlysValue.values.toSet());
    expect(counts.values.toSet(), hasLength(1)); // même compte partout
  });

  test('aucune maxime vide ni dupliquée', () {
    expect(carlysQuotes.every((quote) => quote.text.trim().isNotEmpty), isTrue);
    final texts = carlysQuotes.map((quote) => quote.text).toSet();
    expect(texts, hasLength(carlysQuotes.length));
  });

  group('le ton de la marque', () {
    /// Les registres proscrits, et le mot qui les trahit.
    ///
    /// Carlys est exigeante, jamais culpabilisante : elle accompagne sans
    /// juger, et « essayer » y vaut mieux que « réussir parfaitement ». Une
    /// première série de maximes avait glissé dans tous ces registres à la
    /// fois sans qu'aucun test ne bronche, parce qu'aucun ne parlait du TON.
    const forbidden = <String, List<String>>{
      'la culpabilité': [
        'compte double',
        'aucune excuse',
        'pas d’excuse',
        'ne romps pas',
        'tu n’as pas le droit',
        'honte',
        'paresse',
        'faible',
      ],
      'le culte de la douleur': [
        'souffre',
        'souffrir',
        'la douleur a raison',
        'écoute la douleur',
        'no pain',
        'jusqu’à l’échec',
      ],
      'le perfectionnisme': [
        'parfaitement',
        'sans faute',
        'irréprochable',
      ],
      'le jugement du corps': [
        'ne ment pas',
        'gros',
        'maigre',
        'ton reflet',
      ],
    };

    for (final entry in forbidden.entries) {
      test('aucune maxime ne verse dans ${entry.key}', () {
        for (final quote in carlysQuotes) {
          final text = quote.text.toLowerCase();
          for (final word in entry.value) {
            expect(
              text.contains(word),
              isFalse,
              reason: '« ${quote.text} » contient « $word »',
            );
          }
        }
      });
    }

    test('chaque valeur promet quelque chose, sans donner d’ordre', () {
      // Le libellé et la promesse s'affichent tels quels dans le profil de
      // progression : ils doivent tenir sur une ligne et rester une
      // invitation, pas une injonction.
      for (final value in CarlysValue.values) {
        expect(value.label.trim(), isNotEmpty);
        expect(value.promise.trim(), isNotEmpty);
        expect(value.promise.length, lessThan(60));
        expect(value.promise, isNot(contains('!')));
      }
    });
  });
}
