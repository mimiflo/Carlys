import 'package:carlys_mobile/features/dashboard/data/daily_quotes.dart';
import 'package:carlys_mobile/features/dashboard/domain/entities/daily_quote.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le recueil et sa rotation.
///
/// Deux garanties tiennent la fonctionnalité : la maxime ne change pas dans
/// la journée, et deux jours de suite ne servent jamais la même valeur.
void main() {
  test('la ROTATION ne bouge pas au fil de la journée', () {
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
      'le perfectionnisme': ['parfaitement', 'sans faute', 'irréprochable'],
      'le jugement du corps': ['ne ment pas', 'gros', 'maigre', 'ton reflet'],
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

  group('l’entrelacement est construit, pas confié à la vigilance', () {
    test('un cycle sert une maxime de chaque valeur, dans l’ordre', () {
      final compose = entrelacer(const {
        CarlysValue.constance: [QuoteEntry('c1'), QuoteEntry('c2')],
        CarlysValue.maitrise: [QuoteEntry('m1'), QuoteEntry('m2')],
        CarlysValue.performance: [QuoteEntry('p1'), QuoteEntry('p2')],
        CarlysValue.discipline: [QuoteEntry('d1'), QuoteEntry('d2')],
        CarlysValue.equilibre: [QuoteEntry('e1'), QuoteEntry('e2')],
      });

      expect(compose.map((q) => q.text).toList(), [
        'c1',
        'm1',
        'p1',
        'd1',
        'e1',
        'c2',
        'm2',
        'p2',
        'd2',
        'e2',
      ]);
      expect(compose.first.value, CarlysValue.constance);
      expect(compose[4].value, CarlysValue.equilibre);
    });

    test('des listes inégales sont REFUSÉES, jamais tronquées en silence', () {
      // C'est la faute qu'on attend : quelqu'un ajoute une maxime à une
      // seule valeur. Tronquer perdrait la maxime sans le dire ; composer
      // quand même casserait l'alternance sur la fin du cycle.
      expect(
        () => entrelacer(const {
          CarlysValue.constance: [QuoteEntry('c1'), QuoteEntry('c2')],
          CarlysValue.maitrise: [QuoteEntry('m1')],
          CarlysValue.performance: [QuoteEntry('p1')],
          CarlysValue.discipline: [QuoteEntry('d1')],
          CarlysValue.equilibre: [QuoteEntry('e1')],
        }),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('constance 2'), contains('maitrise 1')),
          ),
        ),
      );
    });

    test('une maxime ÉTIQUETÉE ne déséquilibre pas la rotation', () {
      // Elle ne tourne pas : l'invariant ne porte que sur les maximes sans
      // contexte. Sans cette distinction, ajouter trois maximes de reprise
      // à la constance aurait fait lever `entrelacer`.
      final compose = entrelacer(const {
        CarlysValue.constance: [
          QuoteEntry('c1'),
          QuoteEntry('reprise', contexts: {QuoteContext.retourApresPause}),
        ],
        CarlysValue.maitrise: [QuoteEntry('m1')],
        CarlysValue.performance: [QuoteEntry('p1')],
        CarlysValue.discipline: [QuoteEntry('d1')],
        CarlysValue.equilibre: [QuoteEntry('e1')],
      });

      expect(compose.map((q) => q.text), ['c1', 'm1', 'p1', 'd1', 'e1']);
    });

    test('le recueil réel est composé de cycles entiers', () {
      final tailles = quotesByValue.values
          .map((l) => l.where((m) => m.contexts.isEmpty).length)
          .toSet();
      expect(
        tailles,
        hasLength(1),
        reason:
            'Les cinq listes de maximes SANS CONTEXTE doivent rester de '
            'même longueur : les ajouts de rotation se font par cycles de '
            'cinq. Les maximes étiquetées, elles, sont libres.',
      );
      expect(
        carlysQuotes,
        hasLength(tailles.single * CarlysValue.values.length),
      );
    });
  });

  group('le piège : une maxime contextuelle servie hors contexte', () {
    /// LE DÉFAUT QUE CE GROUPE FERME, et qui était LIVRÉ.
    ///
    /// Trois maximes de la rotation parlaient d'un état qu'elles ne
    /// vérifiaient pas. « Après une pause, reprends plus léger » s'affichait
    /// à tout le monde un jour sur soixante — y compris à quelqu'un qui
    /// s'entraîne depuis six mois sans en manquer une. Le premier geste du
    /// plan n'a donc pas été d'ajouter des maximes, mais de sortir
    /// celles-là de la rotation en les étiquetant.

    test('aucune maxime de la ROTATION ne porte d’étiquette', () {
      // La garantie PAR CONSTRUCTION : le repli calendaire ne peut pas
      // servir une maxime écrite pour un contexte.
      for (final maxime in carlysQuotes) {
        expect(
          maxime.isRotating,
          isTrue,
          reason: '« ${maxime.text} » tourne alors qu’elle est étiquetée',
        );
      }
    });

    test(
      'la rotation ne sert jamais une maxime contextuelle, sur deux tours',
      () {
        for (var jour = 0; jour < carlysQuotes.length * 2; jour++) {
          expect(quoteOfTheDay(DateTime(2026, 1, 1 + jour)).contexts, isEmpty);
        }
      },
    );

    /// Le garde LEXICAL, bâti comme le garde de ton juste au-dessus.
    ///
    /// Le test structurel ne dit rien d'une maxime qui PARLE d'un état sans
    /// porter l'étiquette — c'est exactement l'erreur d'origine. Celui-ci
    /// attrape le vocabulaire.
    /// Des marqueurs qui AFFIRMENT l'état, jamais qui l'évoquent. « Le plus
    /// dur n'est pas la première séance, c'est la troisième semaine » parle
    /// bien d'une première séance sans prétendre que c'est aujourd'hui : une
    /// maxime générale reste une maxime générale, et la liste ne doit pas la
    /// chasser de la rotation.
    const marqueurs = <QuoteContext, List<String>>{
      QuoteContext.retourApresPause: [
        'après une pause',
        'te revoilà',
        'te voilà',
        'content de te revoir',
      ],
      QuoteContext.pauseEnCours: ['sauter une séance', 'depuis ton absence'],
      QuoteContext.seanceAbandonnee: ['abandonnée', 'écourtée hier'],
      QuoteContext.premiereSeance: ['ta première séance', 'tout commence ici'],
      QuoteContext.surcharge: ['sept séances', 'repose-toi'],
      QuoteContext.recordBattu: ['ce record', 'savoure-le'],
      QuoteContext.objectifAtteint: ['objectif atteint'],
    };

    for (final entry in marqueurs.entries) {
      test('aucune maxime de rotation ne parle de ${entry.key.name}', () {
        for (final maxime in carlysQuotes) {
          final texte = maxime.text.toLowerCase();
          for (final mot in entry.value) {
            expect(
              texte.contains(mot),
              isFalse,
              reason:
                  '« ${maxime.text} » parle de ${entry.key.name} sans porter '
                  'l’étiquette : elle tombera dans la rotation, et se lira '
                  'comme une erreur un jour sur ${carlysQuotes.length}.',
            );
          }
        }
      });
    }

    test('chaque contexte a au moins une maxime rédigée', () {
      // Un contexte sans corpus se saute sans bruit — c'est voulu, ça permet
      // d'ajouter un contexte avant ses phrases. Mais douze contextes muets
      // rendraient la tranche entière décorative.
      for (final contexte in QuoteContext.values) {
        expect(
          carlysContextualQuotes.any((m) => m.contexts.contains(contexte)),
          isTrue,
          reason: 'aucune maxime pour ${contexte.name}',
        );
      }
    });
  });
}
