import 'package:carlys_mobile/features/mentor/domain/mentor_tour.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_tour_chemin.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_tour_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// La visite guidée : un manifeste intègre, un avancement dérivé, et une
/// destination pour chaque étape.
void main() {
  group('le manifeste', () {
    test('sept étapes, identifiants uniques, textes complets', () {
      expect(mentorTour, hasLength(7));
      final ids = mentorTour.map((step) => step.id).toSet();
      expect(ids.length, mentorTour.length);
      for (final step in mentorTour) {
        expect(step.titre.trim(), isNotEmpty, reason: step.id);
        expect(step.corps.trim(), isNotEmpty, reason: step.id);
        expect(step.libelleAller.trim(), isNotEmpty, reason: step.id);
      }
    });

    test('chaque étape a sa destination dans la table des routes', () {
      // La table vit dans la présentation (le domaine ignore le routeur) :
      // sans ce test, une étape ajoutée au manifeste mais pas à la table
      // aurait un bouton qui ne mène nulle part.
      for (final step in mentorTour) {
        expect(mentorTourRoutes.keys, contains(step.id));
      }
      // Et pas de destination orpheline non plus.
      expect(mentorTourRoutes.length, mentorTour.length);
    });

    test('chaque étape a son image dans la table des icônes', () {
      // Même garde que pour les routes : le chemin des pastilles montre
      // chaque pièce avec le dessin de son onglet, jamais un repli muet.
      for (final step in mentorTour) {
        expect(mentorTourIcons.keys, contains(step.id));
      }
      expect(mentorTourIcons.length, mentorTour.length);
    });
  });

  group('l’avancement dérivé', () {
    test('reprend à la PREMIÈRE étape non vue, dans l’ordre', () {
      final progress = computeMentorTour({'accueil', 'entrainement'});
      expect(progress.vues, 2);
      expect(progress.prochaine?.id, 'nutrition');
      expect(progress.terminee, isFalse);
    });

    test('une étape sautée reste la prochaine : l’ordre est le manifeste', () {
      final progress = computeMentorTour({'accueil', 'nutrition'});
      expect(progress.prochaine?.id, 'entrainement');
    });

    test('tout vu : la visite est terminée', () {
      final progress = computeMentorTour(
        mentorTour.map((step) => step.id).toSet(),
      );
      expect(progress.terminee, isTrue);
      expect(progress.prochaine, isNull);
      expect(progress.vues, mentorTour.length);
    });

    test('un identifiant inconnu (étape retirée) est ignoré, pas compté', () {
      final progress = computeMentorTour({'accueil', 'etape-disparue'});
      expect(progress.vues, 1);
      expect(progress.prochaine?.id, 'entrainement');
    });
  });
}
