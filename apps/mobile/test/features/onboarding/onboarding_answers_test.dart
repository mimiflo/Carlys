import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/onboarding/domain/onboarding_answers.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les réponses d'onboarding survivent au stockage local : c'est ce qui
/// permet de répondre AVANT d'avoir un compte, identité Carlys comprise.
void main() {
  test('l’identité Carlys fait l’aller-retour par le stockage', () {
    const answers = OnboardingAnswers(
      carlysProfile: CarlysProfile.stratege,
      trainingGoal: TrainingGoal.hyrox,
      goal: NutritionGoal.gainMuscle,
    );

    final restored = OnboardingAnswers.fromStorage(answers.toStorage());

    expect(restored.carlysProfile, CarlysProfile.stratege);
    expect(restored.trainingGoal, TrainingGoal.hyrox);
    expect(restored.goal, NutritionGoal.gainMuscle);
  });

  test('un objectif d’entraînement seul n’est pas « vide », et il n’est '
      'pas métabolique', () {
    const answers = OnboardingAnswers(trainingGoal: TrainingGoal.marathon);

    expect(answers.isEmpty, isFalse);
    // Il part par SON endpoint, jamais par le profil métabolique.
    expect(answers.hasMetabolicAnswers, isFalse);
  });

  test(
    'une identité seule n’est pas « vide » — elle mérite l’enregistrement',
    () {
      const answers = OnboardingAnswers(
        carlysProfile: CarlysProfile.challenger,
      );

      expect(answers.isEmpty, isFalse);
      // Mais elle ne justifie AUCUNE écriture sur le profil métabolique.
      expect(answers.hasMetabolicAnswers, isFalse);
    },
  );

  test('une valeur inconnue relue du stockage est ignorée, pas devinée', () {
    final restored = OnboardingAnswers.fromStorage(const {
      'profilCarlys': 'GUERRIER',
      'objectifEntrainement': 'TRIATHLON',
    });

    expect(restored.carlysProfile, isNull);
    expect(restored.trainingGoal, isNull);
    expect(restored.isEmpty, isTrue);
  });
}
