/// Préférences locales du PARCOURS DE PREMIÈRE OUVERTURE.
///
/// Sans ces valeurs, toute application montée dans un test repart du tunnel
/// (onboarding → compte → Premium) : les tests qui visent un autre écran
/// déclarent donc un appareil dont le parcours est déjà terminé.
library;

import 'package:carlys_mobile/features/onboarding/data/first_run_store.dart';
import 'package:carlys_mobile/features/onboarding/domain/first_run_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Appareil dont le parcours est terminé : démarrage direct sur l'accueil.
void seedCompletedFirstRun([Map<String, Object> extra = const {}]) =>
    seedFirstRunStep(FirstRunStep.done, extra);

/// Appareil neuf : le parcours n'a jamais été ouvert.
void seedFirstOpen([Map<String, Object> extra = const {}]) =>
    SharedPreferences.setMockInitialValues({...extra});

/// Appareil arrêté à une étape précise du parcours.
void seedFirstRunStep(
  FirstRunStep step, [
  Map<String, Object> extra = const {},
]) => SharedPreferences.setMockInitialValues({
  FirstRunStore.stepKey: step.storageValue,
  ...extra,
});
