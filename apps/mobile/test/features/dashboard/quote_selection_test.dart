import 'package:carlys_mobile/features/dashboard/data/daily_quotes.dart';
import 'package:carlys_mobile/features/dashboard/domain/entities/daily_quote.dart';
import 'package:carlys_mobile/features/dashboard/domain/quote_facts.dart';
import 'package:carlys_mobile/features/dashboard/domain/quote_selection.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE CHOIX de la maxime : ce que les faits autorisent à dire.
///
/// Le défaut que cette tranche répare n'était pas une maxime manquante mais
/// une maxime SERVIE À TORT : « Après une pause, reprends plus léger »
/// s'affichait un jour sur soixante à tout le monde, y compris à quelqu'un
/// qui ne s'était pas arrêté. Les tests ci-dessous ferment ce défaut par les
/// deux bouts : le balayage prouve qu'il ne revient plus, les prédicats
/// prouvent que chaque contexte dit bien ce qu'il prétend.
void main() {
  group('le balayage : soixante jours sans jamais lire une phrase fausse', () {
    /// **Le balayage sur soixante jours est le cœur du test.** Une assertion
    /// sur un seul jour passerait par chance cinquante-neuf fois sur
    /// soixante, et la CI serait verte cinquante-neuf jours sur soixante —
    /// c'est-à-dire exactement aussi verte qu'elle l'était pendant que le
    /// défaut était livré.
    ///
    /// Le cycle de rotation fait [carlysQuotes.length] jours : le balayage
    /// couvre donc un tour complet, et en couvre deux par sécurité.

    /// Les trois contextes qui AFFIRMENT une absence. Aucun ne peut être
    /// vrai pour quelqu'un qui s'entraîne tous les jours, et aucune maxime
    /// qui les porte ne doit donc lui être servie.
    const interdits = {
      QuoteContext.retourApresPause,
      QuoteContext.pauseEnCours,
      QuoteContext.semaineCreuse,
    };

    test('qui s’entraîne chaque jour ne lit jamais qu’il s’est arrêté', () {
      for (var jour = 0; jour < carlysQuotes.length * 2; jour++) {
        final today = DateTime(2026, 1, 1 + jour, 20);
        final maxime = contextualQuote(facts: _assidu(today), day: today);

        expect(
          maxime.contexts.intersection(interdits),
          isEmpty,
          reason:
              'Jour $jour ($today) : « ${maxime.text} » parle d’une absence '
              'à quelqu’un qui s’est entraîné ce jour-là et les trente '
              'précédents.',
        );

        // Et le balayage n'est pas vide de sens : sans cette ligne, il
        // passerait encore si `contextualQuote` ne servait plus JAMAIS de
        // maxime contextuelle — la rotation n'en porte aucune, donc
        // l'assertion du dessus serait vraie par accident.
        expect(
          maxime.contexts,
          contains(QuoteContext.serieEnCours),
          reason: 'jour $jour : la série de trente jours n’est pas vue',
        );
      }
    });

    test('et il ne lit jamais une maxime hors du recueil', () {
      // Le corollaire : la sélection ne fabrique rien. Ce qu'elle sert vient
      // soit de la rotation, soit du corpus contextuel — jamais d'ailleurs.
      final connues = {
        ...carlysQuotes.map((m) => m.text),
        ...carlysContextualQuotes.map((m) => m.text),
      };
      for (var jour = 0; jour < carlysQuotes.length * 2; jour++) {
        final today = DateTime(2026, 1, 1 + jour, 20);
        expect(
          connues,
          contains(contextualQuote(facts: _assidu(today), day: today).text),
        );
      }
    });

    test('sans aucun fait, c’est la rotation d’origine, jour pour jour', () {
      // Le repli n'est pas « une maxime au hasard » : c'est LA rotation
      // calendaire, inchangée. Quelqu'un qui n'a aucun fait à son actif —
      // hors ligne au premier lancement, par exemple — lit exactement ce
      // qu'il lisait avant cette tranche.
      for (var jour = 0; jour < carlysQuotes.length * 2; jour++) {
        final today = DateTime(2026, 1, 1 + jour, 20);
        expect(
          contextualQuote(facts: _sansContexte(today), day: today).text,
          quoteOfTheDay(today).text,
          reason: 'jour $jour',
        );
      }
    });
  });

  group('le miroir : revenir et être absent ne sont pas le même fait', () {
    /// [QuoteContext.retourApresPause] exige une séance **aujourd'hui**
    /// après l'écart, tandis que [QuoteContext.pauseEnCours] exige qu'il n'y
    /// en ait **pas**. Sans la première condition, on dirait « content de te
    /// revoir » à qui n'est pas revenu ; sans la seconde, à qui n'est jamais
    /// parti. Les deux erreurs sont symétriques, et toutes les deux
    /// s'écrivent en oubliant une ligne.

    test('deux heures de repos ne sont pas un retour', () {
      final today = DateTime(2026, 8, 12, 20);
      final facts = QuoteFacts(
        today: today,
        completedSessions: 40,
        lastCompletedAt: today.subtract(const Duration(hours: 2)),
        previousCompletedAt: today.subtract(const Duration(days: 1)),
        streakDays: 2,
        trainedThisWeek: 3,
      );

      expect(facts.trainedToday, isTrue);
      expect(facts.gapBeforeLast, 1);
      expect(
        activeContexts(facts),
        isNot(contains(QuoteContext.retourApresPause)),
      );
      expect(activeContexts(facts), isNot(contains(QuoteContext.pauseEnCours)));
    });

    test('quatorze jours sans rien : une pause EN COURS, pas un retour', () {
      final today = DateTime(2026, 8, 12, 20);
      final facts = QuoteFacts(
        today: today,
        completedSessions: 40,
        lastCompletedAt: today.subtract(const Duration(days: 14)),
        previousCompletedAt: today.subtract(const Duration(days: 16)),
      );

      expect(facts.trainedToday, isFalse);
      expect(facts.daysSinceLast, 14);
      expect(
        activeContexts(facts),
        isNot(contains(QuoteContext.retourApresPause)),
      );
      expect(activeContexts(facts), contains(QuoteContext.pauseEnCours));
    });

    test('la même absence, refermée par une séance du jour : un RETOUR', () {
      final today = DateTime(2026, 8, 12, 20);
      final facts = QuoteFacts(
        today: today,
        completedSessions: 41,
        lastCompletedAt: today.subtract(const Duration(hours: 3)),
        previousCompletedAt: today.subtract(const Duration(days: 14)),
      );

      expect(activeContexts(facts), contains(QuoteContext.retourApresPause));
      expect(activeContexts(facts), isNot(contains(QuoteContext.pauseEnCours)));
    });

    test('les deux ne sont JAMAIS vrais ensemble', () {
      // La preuve structurelle, sur toutes les combinaisons d'écarts qui
      // comptent : de part et d'autre des deux seuils, séance du jour ou
      // non.
      for (final ecart in [0, 1, 3, 4, 5, 9, 10, 11, 30]) {
        for (final aujourdhui in [true, false]) {
          final today = DateTime(2026, 8, 12, 20);
          final derniere = aujourdhui
              ? today.subtract(const Duration(hours: 2))
              : today.subtract(Duration(days: ecart + 1));
          final facts = QuoteFacts(
            today: today,
            completedSessions: 20,
            lastCompletedAt: derniere,
            previousCompletedAt: derniere.subtract(Duration(days: ecart + 1)),
          );
          final actifs = activeContexts(facts);
          expect(
            actifs.contains(QuoteContext.retourApresPause) &&
                actifs.contains(QuoteContext.pauseEnCours),
            isFalse,
            reason: 'écart $ecart, séance aujourd’hui : $aujourdhui',
          );
        }
      }
    });
  });

  group('la priorité, là où deux faits vrais se contredisent', () {
    test('la surcharge passe devant la série : la santé avant l’éloge', () {
      final today = DateTime(2026, 8, 12, 20);
      final facts = QuoteFacts(
        today: today,
        completedSessions: 60,
        lastCompletedAt: today.subtract(const Duration(hours: 2)),
        previousCompletedAt: today.subtract(const Duration(days: 1)),
        streakDays: 7,
        trainedThisWeek: 7,
      );

      final actifs = activeContexts(facts);
      expect(actifs, contains(QuoteContext.surcharge));
      expect(actifs, contains(QuoteContext.serieEnCours));
      expect(
        actifs.indexOf(QuoteContext.surcharge),
        lessThan(actifs.indexOf(QuoteContext.serieEnCours)),
      );
      expect(
        contextualQuote(facts: facts, day: today).contexts,
        contains(QuoteContext.surcharge),
      );
    });

    test(
      'le retour passe devant le record : le record est déjà dit ailleurs',
      () {
        final today = DateTime(2026, 8, 12, 20);
        final facts = QuoteFacts(
          today: today,
          completedSessions: 41,
          lastCompletedAt: today.subtract(const Duration(hours: 3)),
          previousCompletedAt: today.subtract(const Duration(days: 21)),
          recentRecordAt: today.subtract(const Duration(hours: 3)),
        );

        final actifs = activeContexts(facts);
        expect(actifs, contains(QuoteContext.recordBattu));
        expect(
          contextualQuote(facts: facts, day: today).contexts,
          contains(QuoteContext.retourApresPause),
        );
      },
    );

    test('à faits constants, la maxime ne bouge pas de la journée', () {
      // Le contrat de stabilité a changé de forme, pas de nature : ce n'est
      // plus « la même toute la journée » mais « la même TANT QUE LES FAITS
      // NE CHANGENT PAS ». À faits identiques, deux appareils lisent la
      // même phrase.
      final matin = DateTime(2026, 8, 12, 6, 30);
      final soir = DateTime(2026, 8, 12, 23, 30);
      final facts = QuoteFacts(
        today: matin,
        completedSessions: 12,
        lastCompletedAt: matin.subtract(const Duration(days: 6)),
        previousCompletedAt: matin.subtract(const Duration(days: 8)),
      );

      expect(
        contextualQuote(facts: facts, day: matin).text,
        contextualQuote(facts: facts, day: soir).text,
      );
    });
  });

  group('les faits se construisent depuis l’historique, sans horloge', () {
    test('un abandon se dit, et une séance terminée depuis l’efface', () {
      final today = DateTime(2026, 8, 12, 20);
      final abandonnee = _entry(
        today.subtract(const Duration(hours: 2)),
        WorkoutStatus.abandoned,
      );
      final terminee = _entry(
        today.subtract(const Duration(hours: 5)),
        WorkoutStatus.completed,
      );

      final avec = buildQuoteFacts(
        today: today,
        history: [abandonnee, terminee],
      );
      expect(avec.lastSessionAbandoned, isTrue);
      expect(avec.completedSessions, 1);

      // Une séance terminée APRÈS l'abandon reprend la main : on ne rappelle
      // pas un échec dépassé.
      final apres = buildQuoteFacts(
        today: today,
        history: [
          abandonnee,
          terminee,
          _entry(today.subtract(const Duration(minutes: 20))),
        ],
      );
      expect(apres.lastSessionAbandoned, isFalse);
      expect(apres.trainedToday, isTrue);
    });

    test('l’écart AVANT la dernière séance se lit en jours civils', () {
      // Deux séances à 23 h et 1 h sont à deux heures l'une de l'autre et
      // pourtant à un jour d'écart : c'est le jour qui compte.
      final today = DateTime(2026, 8, 12, 20);
      final facts = buildQuoteFacts(
        today: today,
        history: [
          _entry(DateTime(2026, 8, 12, 1)),
          _entry(DateTime(2026, 8, 11, 23)),
        ],
      );

      expect(facts.gapBeforeLast, 1);
      expect(facts.trainedToday, isTrue);
    });

    test('un historique vide dit « première séance », sans rien inventer', () {
      final today = DateTime(2026, 8, 12, 20);
      final facts = buildQuoteFacts(today: today, history: const []);

      expect(facts.completedSessions, 0);
      expect(facts.daysSinceLast, isNull);
      expect(facts.gapBeforeLast, isNull);
      expect(activeContexts(facts).first, QuoteContext.premiereSeance);
      expect(
        contextualQuote(facts: facts, day: today).contexts,
        contains(QuoteContext.premiereSeance),
      );
    });
  });
}

/// Les faits de quelqu'un qui s'entraîne tous les jours depuis un mois.
QuoteFacts _assidu(DateTime today) => buildQuoteFacts(
  today: today,
  history: [
    for (var recul = 0; recul <= 30; recul++)
      _entry(today.subtract(Duration(days: recul, hours: 2))),
  ],
  streakDays: 30,
  // Cinq séances : assez pour la série, pas assez pour la surcharge. Le
  // balayage ne teste pas la surcharge, il teste l'absence.
  trainedThisWeek: 5,
);

/// Un parcours ORDINAIRE, dont aucun contexte n'est vrai : deux séances
/// cette semaine, celle du jour comprise, rien de remarquable ni d'alarmant.
/// C'est le cas le plus fréquent, et celui où la rotation reprend la main.
QuoteFacts _sansContexte(DateTime today) => QuoteFacts(
  today: today,
  completedSessions: 12,
  lastCompletedAt: today.subtract(const Duration(hours: 2)),
  previousCompletedAt: today.subtract(const Duration(days: 1)),
  streakDays: 2,
  trainedThisWeek: 2,
);

WorkoutHistoryEntry _entry(
  DateTime startedAt, [
  WorkoutStatus status = WorkoutStatus.completed,
]) => WorkoutHistoryEntry(
  session: WorkoutInfo(
    id: 'w-${startedAt.toIso8601String()}',
    status: status,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 50)),
    durationSeconds: 3000,
    syncState: LocalSyncState.synced,
  ),
  setsCount: 12,
  totalVolumeKg: 4200,
);
