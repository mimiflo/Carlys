import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/onboarding/domain/onboarding_answers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les réponses d'onboarding survivent au stockage local : c'est ce qui
/// permet de répondre AVANT d'avoir un compte, identité Carlys comprise.
void main() {
  test('l’identité Carlys fait l’aller-retour par le stockage', () {
    const answers = OnboardingAnswers(
      carlysProfile: CarlysProfile.stratege,
      goal: NutritionGoal.gainMuscle,
    );

    final restored = OnboardingAnswers.fromStorage(answers.toStorage());

    expect(restored.carlysProfile, CarlysProfile.stratege);
    expect(restored.goal, NutritionGoal.gainMuscle);
  });

  test('une identité seule n’est pas « vide » — elle mérite l’enregistrement',
      () {
    const answers = OnboardingAnswers(carlysProfile: CarlysProfile.challenger);

    expect(answers.isEmpty, isFalse);
    // Mais elle ne justifie AUCUNE écriture sur le profil métabolique.
    expect(answers.hasMetabolicAnswers, isFalse);
  });

  test('une valeur inconnue relue du stockage est ignorée, pas devinée', () {
    final restored = OnboardingAnswers.fromStorage(const {
      'profilCarlys': 'GUERRIER',
    });

    expect(restored.carlysProfile, isNull);
    expect(restored.isEmpty, isTrue);
  });
}
