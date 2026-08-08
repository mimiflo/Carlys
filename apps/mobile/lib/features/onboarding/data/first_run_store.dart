import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/first_run_step.dart';
import '../domain/onboarding_answers.dart';

/// Persistance locale du parcours de première ouverture.
///
/// SharedPreferences suffit : ni l'étape atteinte ni les réponses de profil
/// ne sont des secrets (les jetons, eux, vivent dans le stockage sécurisé).
class FirstRunStore {
  const FirstRunStore();

  /// Étape atteinte du parcours.
  static const String stepKey = 'parcours.premiere_ouverture.etape';

  /// Réponses d'onboarding en attente de compte.
  static const String answersKey = 'parcours.premiere_ouverture.reponses';

  Future<FirstRunStep> readStep() async {
    final prefs = await SharedPreferences.getInstance();
    return FirstRunStep.fromStorage(prefs.getString(stepKey));
  }

  Future<void> writeStep(FirstRunStep step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(stepKey, step.storageValue);
  }

  /// `null` si aucune réponse n'attend d'être enregistrée.
  Future<OnboardingAnswers?> readAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(answersKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    return OnboardingAnswers.fromStorage(decoded);
  }

  Future<void> writeAnswers(OnboardingAnswers answers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(answersKey, jsonEncode(answers.toStorage()));
  }

  Future<void> clearAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(answersKey);
  }
}

final firstRunStoreProvider = Provider<FirstRunStore>(
  (ref) => const FirstRunStore(),
);
