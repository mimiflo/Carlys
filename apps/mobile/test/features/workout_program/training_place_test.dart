import 'package:carlys_mobile/features/workout_program/domain/entities/training_place.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un lieu = une liste de matériel du catalogue, et l'inverse : le lieu se
/// reconnaît à sa liste EXACTE.
void main() {
  const catalogue = [
    'poids-du-corps',
    'barre',
    'halteres',
    'kettlebell',
    'machine',
    'poulie',
    'banc',
    'elastique',
    'barre-de-traction',
    'tapis',
  ];

  test('chaque lieu écrit son matériel, parmi le catalogue seulement', () {
    expect(TrainingPlace.gym.kitIn(catalogue), catalogue);
    expect(TrainingPlace.home.kitIn(catalogue), [
      'poids-du-corps',
      'halteres',
      'kettlebell',
      'banc',
      'elastique',
      'barre-de-traction',
      'tapis',
    ]);
    expect(TrainingPlace.bodyweight.kitIn(catalogue), [
      'poids-du-corps',
      'tapis',
    ]);
    // Un catalogue sans tapis : le tapis n'est jamais écrit.
    expect(TrainingPlace.bodyweight.kitIn(['poids-du-corps']), [
      'poids-du-corps',
    ]);
  });

  test('le lieu se reconnaît à sa liste exacte, sinon c’est le détail', () {
    for (final place in TrainingPlace.values) {
      expect(
        TrainingPlace.matching(place.kitIn(catalogue).toSet(), catalogue),
        place,
      );
    }
    expect(TrainingPlace.matching({}, catalogue), isNull);
    expect(TrainingPlace.matching({'barre', 'halteres'}, catalogue), isNull);
  });
}
