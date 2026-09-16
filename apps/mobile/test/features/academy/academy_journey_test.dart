import 'package:carlys_mobile/features/academy/data/academy_pack.dart';
import 'package:carlys_mobile/features/academy/domain/academy_journey.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le Parcours : un ordre de lecture dérivé, jamais un état stocké.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('le manifeste', () {
    test('référence UNIQUEMENT des leçons servies par le pack', () async {
      // La faute silencieuse par excellence : une leçon renommée dans le
      // pack laisserait le parcours pointer dans le vide, et l'étape
      // paraîtrait plus courte sans que personne ne l'ait décidé.
      final lessons = await loadAcademyPack();
      final packIds = lessons.map((lesson) => lesson.id).toSet();
      for (final stage in academyJourney) {
        for (final id in stage.lessonIds) {
          expect(packIds, contains(id), reason: 'Étape ${stage.nom} : $id');
        }
      }
    });

    test('six étapes, rangs 1 à 6, aucune leçon posée deux fois', () {
      expect(academyJourney, hasLength(6));
      for (var i = 0; i < academyJourney.length; i++) {
        expect(academyJourney[i].rang, i + 1);
        expect(academyJourney[i].lessonIds, isNotEmpty);
      }
      final tous = academyJourney.expand((stage) => stage.lessonIds).toList();
      expect(
        tous.toSet().length,
        tous.length,
        reason: 'Une leçon dans deux étapes se validerait deux fois.',
      );
    });
  });

  group('l’avancement dérivé', () {
    const etapes = [
      JourneyStage(rang: 1, nom: 'Un', description: 'd', lessonIds: ['a', 'b']),
      JourneyStage(rang: 2, nom: 'Deux', description: 'd', lessonIds: ['c']),
    ];
    const pack = {'a', 'b', 'c'};

    test('reprend à la PREMIÈRE leçon non lue de l’étape courante', () {
      final progress = computeJourneyProgress(
        stages: etapes,
        packIds: pack,
        answeredIds: {'a'},
      );

      expect(progress.etapeCourante, 0);
      expect(progress.prochaineLecon, 'b');
      expect(progress.etapesTerminees, 0);
    });

    test('une étape finie passe la main à la suivante', () {
      final progress = computeJourneyProgress(
        stages: etapes,
        packIds: pack,
        answeredIds: {'a', 'b'},
      );

      expect(progress.etapeCourante, 1);
      expect(progress.prochaineLecon, 'c');
      expect(progress.etapesTerminees, 1);
    });

    test('tout lu : plus d’étape courante, le parcours est terminé', () {
      final progress = computeJourneyProgress(
        stages: etapes,
        packIds: pack,
        answeredIds: {'a', 'b', 'c'},
      );

      expect(progress.etapeCourante, isNull);
      expect(progress.prochaineLecon, isNull);
      expect(progress.termine, isTrue);
    });

    test('une leçon lue HORS parcours compte dans le parcours', () {
      // La réponse est la même donnée : lire « c » depuis son domaine,
      // avant d'avoir fini l'étape 1, valide déjà l'étape 2.
      final progress = computeJourneyProgress(
        stages: etapes,
        packIds: pack,
        answeredIds: {'c'},
      );

      expect(progress.parEtape[1].termine, isTrue);
      expect(progress.etapeCourante, 0);
    });

    test('une leçon retirée du pack ne bloque JAMAIS une étape', () {
      final progress = computeJourneyProgress(
        stages: etapes,
        packIds: const {'a', 'c'},
        answeredIds: {'a'},
      );

      expect(
        progress.parEtape.first.termine,
        isTrue,
        reason:
            '« b » n’est plus servie : l’étape se juge sur ce qui se lit '
            'encore.',
      );
      expect(progress.etapeCourante, 1);
    });
  });
}
