import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/domain/program_day_move.dart';
import 'package:flutter_test/flutter_test.dart';

/// DÉPLACER UNE CASE : l'arithmétique, cas par cas.
///
/// La feuille d'une case disait déjà « c'est la case qu'il faut déplacer »
/// alors que le geste n'existait pas. Ces épreuves bornent ce que le geste
/// fait, et surtout ce qu'il NE fait pas : il ne perd aucune case, il ne
/// quitte pas la semaine, et il n'invente aucun identifiant.
void main() {
  ProgramDayEntry jour({
    required String id,
    required int dayOfWeek,
    int weekNumber = 1,
    String label = 'Haut du corps',
    bool isRest = false,
    String? templateId = 'modele-1',
  }) => ProgramDayEntry(
    id: id,
    weekNumber: weekNumber,
    dayOfWeek: dayOfWeek,
    label: label,
    isRest: isRest,
    templateId: templateId,
  );

  ProgramDetail programme(List<ProgramDayEntry> jours) => ProgramDetail(
    id: 'prog-1',
    name: 'Prise de masse',
    weeksCount: 4,
    isActive: true,
    startsOn: '2026-09-07',
    days: jours,
  );

  group('vers un jour LIBRE, la case se relocalise', () {
    test('elle change de jour et garde tout le reste', () {
      final avant = programme([jour(id: 'a', dayOfWeek: 2)]);

      final apres = moveProgramDay(
        avant,
        weekNumber: 1,
        fromDayOfWeek: 2,
        toDayOfWeek: 4,
      );

      expect(apres.dayAt(1, 2), isNull);
      final deplacee = apres.dayAt(1, 4);
      expect(deplacee, isNotNull);
      expect(deplacee!.id, 'a', reason: 'la MÊME case, pas une nouvelle');
      expect(deplacee.label, 'Haut du corps');
      expect(deplacee.templateId, 'modele-1');
      expect(deplacee.weekNumber, 1);
    });

    test('les autres semaines ne bougent pas', () {
      // Le piège : `dayAt` cherche par (semaine, jour), mais un filtrage
      // écrit par jour seul emporterait le mardi de TOUTES les semaines.
      final avant = programme([
        jour(id: 'a', dayOfWeek: 2),
        jour(id: 'b', dayOfWeek: 2, weekNumber: 2, label: 'Bas du corps'),
      ]);

      final apres = moveProgramDay(
        avant,
        weekNumber: 1,
        fromDayOfWeek: 2,
        toDayOfWeek: 4,
      );

      expect(apres.days, hasLength(2));
      expect(apres.dayAt(2, 2)?.id, 'b');
      expect(apres.dayAt(1, 4)?.id, 'a');
    });
  });

  group('vers un jour OCCUPÉ, les deux échangent', () {
    test('aucune des deux cases ne disparaît', () {
      final avant = programme([
        jour(id: 'a', dayOfWeek: 2),
        jour(id: 'b', dayOfWeek: 4, label: 'Bas du corps'),
      ]);

      final apres = moveProgramDay(
        avant,
        weekNumber: 1,
        fromDayOfWeek: 2,
        toDayOfWeek: 4,
      );

      expect(apres.days, hasLength(2), reason: 'écraser perdrait une séance');
      expect(apres.dayAt(1, 4)?.id, 'a');
      expect(apres.dayAt(1, 2)?.id, 'b');
      expect(apres.dayAt(1, 2)?.label, 'Bas du corps');
    });

    test('un jour de REPOS s’échange comme les autres', () {
      // Un repos EXPLICITE est une décision, pas un trou : il se déplace.
      final avant = programme([
        jour(id: 'a', dayOfWeek: 3),
        jour(
          id: 'r',
          dayOfWeek: 6,
          label: 'Repos',
          isRest: true,
          templateId: null,
        ),
      ]);

      final apres = moveProgramDay(
        avant,
        weekNumber: 1,
        fromDayOfWeek: 3,
        toDayOfWeek: 6,
      );

      expect(apres.dayAt(1, 3)?.isRest, isTrue);
      expect(apres.dayAt(1, 3)?.templateId, isNull);
      expect(apres.dayAt(1, 6)?.id, 'a');
    });
  });

  group('ce qui ne se déplace pas rend le programme INCHANGÉ', () {
    test('le même jour au départ et à l’arrivée', () {
      final avant = programme([jour(id: 'a', dayOfWeek: 2)]);
      expect(
        identical(
          moveProgramDay(
            avant,
            weekNumber: 1,
            fromDayOfWeek: 2,
            toDayOfWeek: 2,
          ),
          avant,
        ),
        isTrue,
      );
    });

    test('un jour de départ VIDE', () {
      final avant = programme([jour(id: 'a', dayOfWeek: 2)]);
      expect(
        identical(
          moveProgramDay(
            avant,
            weekNumber: 1,
            fromDayOfWeek: 5,
            toDayOfWeek: 6,
          ),
          avant,
        ),
        isTrue,
      );
    });

    test('un jour hors de la semaine, des deux côtés', () {
      // La convention est 1 (lundi) à 7 (dimanche) : 0 et 8 n'existent pas,
      // et une arithmétique modulo les ferait passer pour dimanche et lundi.
      final avant = programme([jour(id: 'a', dayOfWeek: 2)]);
      for (final cible in [0, 8, -1]) {
        expect(
          identical(
            moveProgramDay(
              avant,
              weekNumber: 1,
              fromDayOfWeek: 2,
              toDayOfWeek: cible,
            ),
            avant,
          ),
          isTrue,
          reason: 'jour $cible',
        );
      }
    });
  });
}
