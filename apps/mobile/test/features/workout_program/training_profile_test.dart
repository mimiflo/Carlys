import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/controllers/training_profile_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_training_profile_repository.dart';

/// Les entrées de génération : un niveau assumé, une relecture tolérante.
void main() {
  test('trois expériences, wires uniques, textes complets', () {
    expect(TrainingExperience.values, hasLength(3));
    final wires = TrainingExperience.values
        .map((experience) => experience.wire)
        .toSet();
    expect(wires.length, TrainingExperience.values.length);
    for (final experience in TrainingExperience.values) {
      expect(experience.label.trim(), isNotEmpty, reason: experience.wire);
      expect(
        experience.description.trim(),
        isNotEmpty,
        reason: experience.wire,
      );
    }
  });

  test('un wire inconnu rend null : jamais un niveau deviné', () {
    expect(TrainingExperience.fromWire('EXPERT'), isNull);
    expect(TrainingExperience.fromWire(null), isNull);
    expect(
      TrainingExperience.fromWire('INTERMEDIATE'),
      TrainingExperience.intermediate,
    );
  });

  test(
    'la relecture serveur est tolérante : inconnu vaut null, jamais faux',
    () {
      final profile = trainingProfileFromJson(const {
        'trainingGoal': 'HYROX',
        'trainingExperience': 'EXPERT',
        'weeklySessionsTarget': 4,
        'sessionMinutesTarget': null,
        'equipmentSlugs': ['barre', 7, 'halteres'],
      });

      expect(profile.goal, TrainingGoal.hyrox);
      // Valeur inconnue d'un serveur plus récent : null, pas un plantage.
      expect(profile.experience, isNull);
      expect(profile.weeklySessionsTarget, 4);
      expect(profile.sessionMinutesTarget, isNull);
      // Un élément qui n'est pas une chaîne est écarté, pas converti.
      expect(profile.equipmentSlugs, ['barre', 'halteres']);
    },
  );

  test('une réponse vide rend un profil entièrement nul, liste vide', () {
    final profile = trainingProfileFromJson(const {});
    expect(profile.goal, isNull);
    expect(profile.experience, isNull);
    expect(profile.weeklySessionsTarget, isNull);
    expect(profile.sessionMinutesTarget, isNull);
    expect(profile.equipmentSlugs, isEmpty);
  });

  test('deux bascules de matériel SANS attente s\u2019enchaînent, rien ne '
      's\u2019écrase', () async {
    // La liste est un remplacement COMPLET : sans sérialisation, la
    // seconde bascule calculerait depuis l'état d'avant la première et
    // l'écraserait. Ici : barre puis banc, lancées d'un même geste.
    final repo = FakeTrainingProfileRepository(
      initial: const TrainingProfile(
        goal: null,
        experience: null,
        weeklySessionsTarget: null,
        sessionMinutesTarget: null,
        equipmentSlugs: ['halteres'],
      ),
    );
    final container = ProviderContainer(
      overrides: [trainingProfileRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final actions = container.read(trainingProfileActionsProvider);

    final premiere = actions.toggleEquipment('barre');
    final seconde = actions.toggleEquipment('banc');
    await premiere;
    await seconde;

    expect(repo.equipmentWrites, hasLength(2));
    expect(repo.equipmentWrites.first.toSet(), {'halteres', 'barre'});
    // La seconde REPART de l'état écrit par la première.
    expect(repo.equipmentWrites.last.toSet(), {'halteres', 'barre', 'banc'});
    expect(repo.profile.equipmentSlugs.toSet(), {'halteres', 'barre', 'banc'});
  });
}
