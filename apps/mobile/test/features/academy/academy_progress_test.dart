import 'package:carlys_mobile/features/academy/domain/academy_progress.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_progress_card.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/reward_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'avancement dans le pack : un REPÈRE de position, jamais un second score.
void main() {
  Lesson lesson(String id, AcademyCategory category) => Lesson(
    id: id,
    category: category,
    title: id,
    body: 'corps',
    question: const QuizQuestion(
      prompt: 'p',
      choices: ['a', 'b'],
      answerIndex: 0,
      explanation: 'e',
    ),
  );

  final pack = [
    lesson('n1', AcademyCategory.nutrition),
    lesson('n2', AcademyCategory.nutrition),
    lesson('t1', AcademyCategory.technique),
    lesson('t2', AcademyCategory.technique),
    lesson('t3', AcademyCategory.technique),
  ];

  group('le décompte', () {
    test('compte par domaine, et ne sert que les domaines servis', () {
      final progress = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1', 't1', 't2'},
      );

      expect(progress.abordees, 3);
      expect(progress.total, 5);
      expect(progress.domainesServis, 2);
      expect(
        progress.parDomaine.keys,
        [AcademyCategory.nutrition, AcademyCategory.technique],
        reason:
            'Les dix autres domaines n’ont aucune leçon : leur donner une '
            'entrée vide ferait afficher « 0 / 0 ».',
      );
      expect(progress.parDomaine[AcademyCategory.nutrition]!.abordees, 1);
      expect(progress.parDomaine[AcademyCategory.technique]!.abordees, 2);
    });

    test('une réponse à une leçon ABSENTE du pack ne compte pas', () {
      // Le magasin local garde les réponses par identifiant : une leçon
      // retirée du pack y reste, et la compter gonflerait l'avancement
      // au-delà du total.
      final progress = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1', 'leçon-retirée-du-pack'},
      );

      expect(progress.abordees, 1);
      expect(progress.abordees, lessThanOrEqualTo(progress.total));
    });

    test('un domaine se boucle quand TOUTES ses leçons sont abordées', () {
      final partiel = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1'},
      );
      expect(partiel.domainesTermines, isEmpty);

      final boucle = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1', 'n2'},
      );
      expect(boucle.domainesTermines, [AcademyCategory.nutrition]);
    });

    test('un domaine vide n’est jamais « bouclé »', () {
      const vide = DomainProgress(abordees: 0, total: 0);
      expect(vide.termine, isFalse, reason: 'Il n’y avait rien à lire.');
      expect(vide.ratio, 0);
    });
  });

  group('la célébration ne se déclenche qu’au franchissement', () {
    test('un domaine qui vient de se boucler est nommé', () {
      final avant = computeAcademyProgress(lessons: pack, answeredIds: {'n1'});
      final apres = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1', 'n2'},
      );

      expect(
        domaineAcheve(avant: avant, apres: apres),
        AcademyCategory.nutrition,
      );
    });

    test('un domaine DÉJÀ bouclé ne se refête pas', () {
      // C'est le vrai risque : lire l'état final rejouerait la fête à
      // chaque ouverture de l'écran.
      final etat = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1', 'n2'},
      );

      expect(domaineAcheve(avant: etat, apres: etat), isNull);
    });

    test('une réponse qui ne boucle rien ne déclenche rien', () {
      final avant = computeAcademyProgress(lessons: pack, answeredIds: {});
      final apres = computeAcademyProgress(lessons: pack, answeredIds: {'t1'});

      expect(domaineAcheve(avant: avant, apres: apres), isNull);
    });
  });

  group('les récompenses de l’Academy se décident sans le reste', () {
    /// Les six règles affichées dans l'Academy.
    Iterable<RewardRule> reglesAcademy() => rewardCatalog.where(
      (regle) => AcademyProgressCard.rewardIds.contains(regle.reward.id),
    );

    test('les six identifiants affichés existent bien au catalogue', () {
      expect(
        reglesAcademy().map((regle) => regle.reward.id).toSet(),
        AcademyProgressCard.rewardIds.toSet(),
        reason:
            'Un identifiant qui ne correspond à rien afficherait un sceau '
            'éteint pour toujours.',
      );
    });

    test('AUCUNE ne dépend du titre atteint', () {
      // C'est ce qui autorise la carte à se passer d'`earnedRewardsProvider`,
      // donc de l'historique des séances : sans cette garantie, l'Academy
      // dépendrait de la base d'entraînement pour afficher SES badges.
      final progress = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1', 'n2', 't1'},
      );
      final base = AcademyProgressCard.factsOf(progress);
      final auSommet = RewardFacts(
        reachedTitle: CarlysTitle.icone,
        lessonsAnswered: base.lessonsAnswered,
        lessonsTotal: base.lessonsTotal,
        academyDomainsCompleted: base.academyDomainsCompleted,
        academyDomainsServed: base.academyDomainsServed,
      );

      for (final regle in reglesAcademy()) {
        expect(
          regle.isEarned(auSommet),
          regle.isEarned(base),
          reason:
              '« ${regle.reward.label} » change de verdict avec le titre : '
              'la carte de l’Academy ne peut plus la décider seule.',
        );
      }
    });

    test('boucler un domaine ouvre « Un domaine bouclé »', () {
      bool gagnee(String id, AcademyProgress progress) => reglesAcademy()
          .firstWhere((regle) => regle.reward.id == id)
          .isEarned(AcademyProgressCard.factsOf(progress));

      final partiel = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1'},
      );
      expect(gagnee('domaines-1', partiel), isFalse);

      final unDomaine = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1', 'n2'},
      );
      expect(gagnee('domaines-1', unDomaine), isTrue);
      expect(gagnee('domaines-tous', unDomaine), isFalse);

      final tout = computeAcademyProgress(
        lessons: pack,
        answeredIds: {'n1', 'n2', 't1', 't2', 't3'},
      );
      expect(gagnee('domaines-tous', tout), isTrue);
      expect(gagnee('maitrise-pack', tout), isTrue);
    });

    test('un pack VIDE n’offre aucune récompense', () {
      // Sans cette garde, « tous les domaines bouclés » serait vrai à
      // l'installation : 0 >= 0.
      const vide = AcademyProgress(abordees: 0, total: 0, parDomaine: {});
      for (final regle in reglesAcademy()) {
        expect(
          regle.isEarned(AcademyProgressCard.factsOf(vide)),
          isFalse,
          reason: '« ${regle.reward.label} » se gagne sur un pack vide.',
        );
      }
    });
  });
}
