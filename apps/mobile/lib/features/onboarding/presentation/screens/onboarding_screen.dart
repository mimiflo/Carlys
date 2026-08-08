import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../nutrition/domain/entities/nutrition.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../widgets/onboarding_backdrop.dart';
import '../widgets/onboarding_birth_date_card.dart';
import '../widgets/onboarding_choices.dart';
import '../widgets/onboarding_cta.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_height_card.dart';
import '../widgets/onboarding_option_card.dart';
import '../widgets/onboarding_step_body.dart';

/// Onboarding (maquette 2a) : 4 étapes qui remplissent le profil
/// métabolique réel (objectif, sexe, naissance/taille, activité).
///
/// Le contenu vit en bas de l'écran, sous le cœur ambient ; « Passer » reste
/// toujours possible — le profil se complète aussi depuis l'onglet Nutrition.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _stepCount = 4;
  static const double _defaultHeightCm = 175;

  int _step = 0;
  NutritionGoal? _goal;
  BiologicalSex? _sex;
  DateTime? _birthDate;
  double _heightCm = _defaultHeightCm;
  bool _heightTouched = false;
  ActivityLevel? _activity;
  bool _saving = false;

  bool get _stepComplete => switch (_step) {
        0 => _goal != null,
        1 => _sex != null,
        2 => _birthDate != null && _heightTouched,
        _ => _activity != null,
      };

  bool get _isLastStep => _step == _stepCount - 1;

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  Future<void> _next() async {
    if (!_isLastStep) {
      setState(() => _step++);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(nutritionActionsProvider).saveProfile(
            MetabolicProfileUpdate(
              goal: _goal,
              sex: _sex,
              birthDate: _birthDate,
              heightCm: _heightTouched ? _heightCm : null,
              activityLevel: _activity,
            ),
          );
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } on AppException catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exception is NetworkException
                ? 'Serveur injoignable — réessaie une fois connecté.'
                : 'Enregistrement impossible. Réessaie dans un instant.',
          ),
        ),
      );
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Ta date de naissance',
    );
    if (picked != null) {
      setState(
        () => _birthDate = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: OnboardingBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.gutter,
                AppSpacing.gutter,
                AppSpacing.gapSection,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OnboardingHeader(
                    step: _step,
                    stepCount: _stepCount,
                    onBack: _step == 0 || _saving ? null : _back,
                  ),
                  Expanded(child: _buildBottomBlock()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Le bloc bas est collé en bas de l'espace disponible, et défile si
  /// l'écran est trop court pour lui.
  Widget _buildBottomBlock() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildStep(),
              const SizedBox(height: AppSpacing.lg),
              OnboardingCta(
                label: _isLastStep ? 'Terminer' : 'Continuer',
                loading: _saving,
                onPressed: _stepComplete ? _next : null,
                onSkip: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => OnboardingStepBody(
          label: 'Ton objectif',
          question: 'Qu’est-ce qu’on\nconstruit ensemble ?',
          subtitle: 'On calibre tes charges, ton volume et tes macros '
              'à partir de ça.',
          options: [
            for (final goal in onboardingGoals)
              OnboardingOptionCard(
                title: goal.label,
                subtitle: goalSubtitle(goal),
                icon: goalIcon(goal),
                selected: _goal == goal,
                onTap: () => setState(() => _goal = goal),
              ),
          ],
        ),
      1 => OnboardingStepBody(
          label: 'Ton profil',
          question: 'Pour calibrer\nton métabolisme',
          subtitle: 'La formule de Mifflin-St Jeor dépend du sexe biologique.',
          options: [
            for (final sex in BiologicalSex.values)
              OnboardingOptionCard(
                title: sex.label,
                icon: sexIcon(sex),
                selected: _sex == sex,
                onTap: () => setState(() => _sex = sex),
              ),
          ],
        ),
      2 => OnboardingStepBody(
          label: 'Tes mesures',
          question: 'Naissance\net taille',
          subtitle: 'L’âge et la taille entrent dans le calcul quotidien.',
          options: [
            OnboardingBirthDateCard(
              birthDate: _birthDate,
              onTap: _pickBirthDate,
            ),
            OnboardingHeightCard(
              heightCm: _heightCm,
              touched: _heightTouched,
              onChanged: (value) => setState(() {
                _heightCm = value;
                _heightTouched = true;
              }),
            ),
          ],
        ),
      _ => OnboardingStepBody(
          label: 'Ton rythme',
          question: 'À quelle fréquence\nbouges-tu ?',
          subtitle: 'Ta dépense d’activité s’ajoute à ton métabolisme de base.',
          options: [
            for (final level in ActivityLevel.values)
              OnboardingOptionCard(
                title: level.label,
                subtitle: level.description,
                icon: activityIcon(level),
                selected: _activity == level,
                onTap: () => setState(() => _activity = level),
              ),
          ],
        ),
    };
  }
}
