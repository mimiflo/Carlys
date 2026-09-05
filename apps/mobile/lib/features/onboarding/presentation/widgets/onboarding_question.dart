import 'package:flutter/material.dart';

import '../../../carlys_profile/domain/entities/carlys_profile.dart';
import '../../../carlys_profile/presentation/widgets/carlys_profile_card.dart';
import '../../../nutrition/domain/entities/nutrition.dart';
import 'onboarding_birth_date_card.dart';
import 'onboarding_choices.dart';
import 'onboarding_height_card.dart';
import 'onboarding_option_card.dart';
import 'onboarding_step_body.dart';

/// Contenu de l'étape courante de l'onboarding : question, sous-titre et
/// options, marqués des réponses déjà données.
///
/// Purement présentationnel — l'état des réponses vit dans l'écran.
class OnboardingQuestion extends StatelessWidget {
  const OnboardingQuestion({
    required this.step,
    required this.carlysProfile,
    required this.goal,
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.heightTouched,
    required this.activityLevel,
    required this.onCarlysProfile,
    required this.onGoal,
    required this.onSex,
    required this.onPickBirthDate,
    required this.onHeight,
    required this.onActivity,
    super.key,
  });

  /// Index de l'étape courante (0 = identité Carlys, 4 = rythme).
  final int step;

  final CarlysProfile? carlysProfile;
  final NutritionGoal? goal;
  final BiologicalSex? sex;
  final DateTime? birthDate;
  final double heightCm;

  /// `false` tant que la taille n'a pas été ajustée : la valeur par défaut
  /// ne vaut pas réponse.
  final bool heightTouched;
  final ActivityLevel? activityLevel;

  final ValueChanged<CarlysProfile> onCarlysProfile;
  final ValueChanged<NutritionGoal> onGoal;
  final ValueChanged<BiologicalSex> onSex;
  final VoidCallback onPickBirthDate;
  final ValueChanged<double> onHeight;
  final ValueChanged<ActivityLevel> onActivity;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      // L'identité OUVRE le parcours : se reconnaître avant de mesurer —
      // c'est l'accroche, et le reste des questions s'y adosse. Les cartes
      // sont CELLES de l'écran Profil Carlys (illustration, titre,
      // description, anneau animé sur la sélection) : même langage visuel
      // du premier écran au dernier.
      0 => OnboardingStepBody(
        label: 'Ton identité',
        question: 'Quel Carlys\nes-tu ?',
        subtitle:
            'Une identité, pas un niveau : tu pourras en changer '
            'à tout moment.',
        options: [
          for (final value in CarlysProfile.values)
            CarlysProfileCard(
              profile: value,
              isCurrent: carlysProfile == value,
              onTap: () => onCarlysProfile(value),
            ),
        ],
      ),
      1 => OnboardingStepBody(
        label: 'Ton objectif',
        question: 'Qu’est-ce qu’on\nconstruit ensemble ?',
        subtitle:
            'On calibre tes charges, ton volume et tes macros '
            'à partir de ça.',
        options: [
          for (final value in onboardingGoals)
            OnboardingOptionCard(
              title: value.label,
              subtitle: goalSubtitle(value),
              icon: goalIcon(value),
              selected: goal == value,
              onTap: () => onGoal(value),
            ),
        ],
      ),
      2 => OnboardingStepBody(
        label: 'Ton profil',
        question: 'Pour calibrer\nton métabolisme',
        subtitle: 'La formule de Mifflin-St Jeor dépend du sexe biologique.',
        options: [
          for (final value in BiologicalSex.values)
            OnboardingOptionCard(
              title: value.label,
              icon: sexIcon(value),
              selected: sex == value,
              onTap: () => onSex(value),
            ),
        ],
      ),
      3 => OnboardingStepBody(
        label: 'Tes mesures',
        question: 'Naissance\net taille',
        subtitle: 'L’âge et la taille entrent dans le calcul quotidien.',
        options: [
          OnboardingBirthDateCard(birthDate: birthDate, onTap: onPickBirthDate),
          OnboardingHeightCard(
            heightCm: heightCm,
            touched: heightTouched,
            onChanged: onHeight,
          ),
        ],
      ),
      _ => OnboardingStepBody(
        label: 'Ton rythme',
        question: 'À quelle fréquence\nbouges-tu ?',
        subtitle: 'Ta dépense d’activité s’ajoute à ton métabolisme de base.',
        options: [
          for (final value in ActivityLevel.values)
            OnboardingOptionCard(
              title: value.label,
              subtitle: value.description,
              icon: activityIcon(value),
              selected: activityLevel == value,
              onTap: () => onActivity(value),
            ),
        ],
      ),
    };
  }
}
