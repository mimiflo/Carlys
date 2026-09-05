import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE BARÈME, au cas par cas.
///
/// Le profil de progression est l'endroit du produit où la marque se trahit
/// le plus facilement : un barème mal posé punit une absence, récompense
/// l'excès, ou invente un zéro là où il n'y a simplement pas encore de
/// données. Ces tests tiennent les trois promesses par écrit.
void main() {
  final today = DateTime(2026, 8, 15);

  /// Jours de séance, comptés à rebours depuis aujourd'hui.
  List<DateTime> daysAgo(List<int> ages) =>
      ages.map((age) => today.subtract(Duration(days: age))).toList();

  ProgressionAxis axisOf(ProgressionProfile profile, CarlysValue value) =>
      profile.axes.firstWhere((axis) => axis.value == value);

  group('un profil vierge', () {
    final profile = computeProgression(ProgressionFacts(today: today));

    test('ne montre AUCUN zéro déguisé : chaque axe dit qu’il attend', () {
      // Un zéro ressemble à un échec. « Pas encore de données » est la
      // vérité, et c'est la seule chose qui n'humilie pas un débutant.
      for (final axis in profile.axes) {
        expect(axis.known, isFalse, reason: axis.value.label);
        expect(axis.reason.trim(), isNotEmpty);
      }
      expect(profile.pending, hasLength(CarlysValue.values.length));
    });

    test('commence Apprenti, sans faire honte', () {
      expect(profile.points, 0);
      expect(profile.title, CarlysTitle.apprenti);
    });

    test('chaque axe en attente dit COMMENT l’ouvrir', () {
      // Carlys explique toujours le pourquoi : un axe vide sans mode
      // d'emploi est une porte fermée.
      for (final axis in profile.pending) {
        expect(
          axis.reason.toLowerCase(),
          anyOf(contains('ouvrir'), contains('ouvrira'), contains('s’ouvre')),
          reason: axis.value.label,
        );
      }
    });
  });

  group('constance', () {
    test('compte les SEMAINES avec séance, pas les jours', () {
      // Compter les jours ferait de la constance un objectif inatteignable.
      final profile = computeProgression(
        ProgressionFacts(
          today: today,
          completedSessionDays: daysAgo([0, 1, 2]),
        ),
      );

      // Trois jours de la même semaine : une seule semaine sur huit.
      expect(
        axisOf(profile, CarlysValue.constance).ratio,
        closeTo(1 / 8, 0.01),
      );
    });

    test('huit semaines servies remplissent l’axe', () {
      final profile = computeProgression(
        ProgressionFacts(
          today: today,
          completedSessionDays: daysAgo([0, 7, 14, 21, 28, 35, 42, 49]),
        ),
      );

      final axis = axisOf(profile, CarlysValue.constance);
      expect(axis.ratio, 1);
      expect(axis.points, maxAxisPoints);
    });

    test('une pause ancienne ne retire rien à la reprise', () {
      // La fenêtre glisse : les points ne se PERDENT pas, ils se
      // recalculent. Reprendre les fait remonter tout de suite.
      final abandoned = computeProgression(
        ProgressionFacts(today: today, completedSessionDays: daysAgo([200])),
      );
      final resumed = computeProgression(
        ProgressionFacts(
          today: today,
          completedSessionDays: daysAgo([200, 2, 9]),
        ),
      );

      expect(axisOf(abandoned, CarlysValue.constance).ratio, 0);
      expect(
        axisOf(resumed, CarlysValue.constance).ratio,
        closeTo(2 / 8, 0.01),
      );
    });
  });

  group('performance', () {
    ProgressionAxis performance(double recent, double previous) => axisOf(
      computeProgression(
        ProgressionFacts(
          today: today,
          recentVolumeKg: recent,
          previousVolumeKg: previous,
        ),
      ),
      CarlysValue.performance,
    );

    test('le maintien vaut déjà la moitié des points', () {
      // Tenir son niveau n'est pas un échec : une sèche ou une blessure ne
      // doivent pas vider l'axe.
      expect(performance(10000, 10000).ratio, closeTo(0.5, 0.001));
    });

    test('une hausse de 20 % remplit l’axe', () {
      expect(performance(12000, 10000).ratio, closeTo(1, 0.001));
    });

    test('une baisse est dite sans jugement', () {
      final axis = performance(8000, 10000);

      expect(axis.ratio, closeTo(0, 0.001));
      expect(axis.reason, contains('fait partie du chemin'));
    });

    test('sans passé à comparer, on crédite le maintien et on le dit', () {
      final axis = performance(5000, 0);

      expect(axis.known, isTrue);
      expect(axis.ratio, 0.5);
      expect(axis.reason, contains('quatre semaines'));
    });
  });

  group('discipline', () {
    test('mesure les séances CLOSES, pas leur longueur', () {
      final profile = computeProgression(
        ProgressionFacts(
          today: today,
          startedSessions: 10,
          completedSessions: 8,
        ),
      );

      expect(
        axisOf(profile, CarlysValue.discipline).ratio,
        closeTo(0.8, 0.001),
      );
    });
  });

  group('équilibre', () {
    double ratioFor(List<int> ages) => axisOf(
      computeProgression(
        ProgressionFacts(today: today, completedSessionDays: daysAgo(ages)),
      ),
      CarlysValue.equilibre,
    ).ratio;

    test('deux à quatre séances par semaine remplissent l’axe', () {
      // 12 séances sur 28 jours = 3 par semaine.
      expect(ratioFor([0, 2, 4, 7, 9, 11, 14, 16, 18, 21, 23, 25]), 1);
    });

    test('s’entraîner TOUS les jours coûte des points', () {
      // L'axe porte la récupération : récompenser le volume maximal
      // contredirait la valeur elle-même.
      final everyDay = List<int>.generate(28, (index) => index);

      expect(ratioFor(everyDay), lessThan(1));
    });

    test('trop peu de séances ne remplit pas l’axe non plus', () {
      expect(ratioFor([0, 14]), lessThan(1));
    });
  });

  group('titres', () {
    test('ils se suivent sans trou ni recouvrement', () {
      var previous = -1;
      for (final title in CarlysTitle.values) {
        expect(title.threshold, greaterThan(previous));
        expect(CarlysTitle.forPoints(title.threshold), title);
        previous = title.threshold;
      }
    });

    test('le dernier titre n’a pas de suite, et sa barre est pleine', () {
      const full = ProgressionProfile(
        axes: [
          ProgressionAxis(
            value: CarlysValue.constance,
            ratio: 1,
            points: maxTotal,
            reason: 'test',
          ),
        ],
      );

      expect(full.title, CarlysTitle.icone);
      expect(full.title.next, isNull);
      expect(full.pointsToNextTitle, isNull);
      expect(full.progressToNextTitle, 1);
    });

    test('le dernier titre reste ATTEIGNABLE avec les cinq axes pleins', () {
      // Un seuil au-dessus du maximum ferait d'« Icône » une carotte
      // inaccessible : exactement le contraire d'un système qui accompagne.
      expect(CarlysTitle.icone.threshold, lessThanOrEqualTo(maxTotal));
    });
  });

  test('un profil complet reste borné', () {
    final profile = computeProgression(
      ProgressionFacts(
        today: today,
        completedSessionDays: daysAgo(List<int>.generate(56, (index) => index)),
        startedSessions: 40,
        completedSessions: 40,
        recentVolumeKg: 100000,
        previousVolumeKg: 1,
        lessonsAnswered: 999,
        lessonsTotal: 22,
      ),
    );

    for (final axis in profile.axes) {
      expect(axis.points, inInclusiveRange(0, maxAxisPoints));
      expect(axis.ratio, inInclusiveRange(0.0, 1.0));
    }
    expect(profile.points, inInclusiveRange(0, maxTotal));
  });
}
