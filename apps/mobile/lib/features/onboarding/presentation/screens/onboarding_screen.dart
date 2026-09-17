import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../carlys_profile/domain/entities/carlys_profile.dart';
import '../../../nutrition/domain/entities/nutrition.dart';
import '../../../workout_program/domain/entities/training_goal.dart';
import '../../domain/onboarding_answers.dart';
import '../controllers/first_run_controller.dart';
import '../widgets/onboarding_backdrop.dart';
import '../widgets/onboarding_cta.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_question.dart';

/// Onboarding : 6 étapes — l'identité Carlys d'abord (se reconnaître est
/// l'accroche du parcours), l'objectif d'ENTRAÎNEMENT ensuite (le pourquoi
/// des séances, distinct de la nutrition), puis le profil métabolique réel
/// (objectif nutritionnel, sexe, naissance/taille, activité).
///
/// Première marche du parcours de première ouverture : les réponses sont
/// enregistrées tout de suite si un compte existe, conservées localement
/// sinon puis reportées sur le profil dès la création du compte — l'identité
/// Carlys suit exactement le même chemin.
///
/// Le contenu vit en bas de l'écran, sous le cœur ambient ; « Passer » reste
/// toujours possible — le profil se complète aussi depuis l'onglet Nutrition.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _stepCount = 6;
  static const double _defaultHeightCm = 175;

  int _step = 0;
  CarlysProfile? _carlysProfile;
  TrainingGoal? _trainingGoal;
  NutritionGoal? _goal;
  BiologicalSex? _sex;
  DateTime? _birthDate;
  double _heightCm = _defaultHeightCm;
  bool _heightTouched = false;
  ActivityLevel? _activity;
  bool _saving = false;

  bool get _stepComplete => switch (_step) {
    0 => _carlysProfile != null,
    1 => _trainingGoal != null,
    2 => _goal != null,
    3 => _sex != null,
    4 => _birthDate != null && _heightTouched,
    _ => _activity != null,
  };

  bool get _isLastStep => _step == _stepCount - 1;

  OnboardingAnswers get _answers => OnboardingAnswers(
    carlysProfile: _carlysProfile,
    trainingGoal: _trainingGoal,
    goal: _goal,
    sex: _sex,
    birthDate: _birthDate,
    heightCm: _heightTouched ? _heightCm : null,
    activityLevel: _activity,
  );

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

  /// Enregistre puis laisse le routeur enchaîner : à la fin du parcours de
  /// première ouverture, `/home` est redirigé vers l'étape suivante.
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(firstRunControllerProvider.notifier)
          .submitOnboarding(_answers);
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
                ? 'Serveur injoignable : réessaie une fois connecté.'
                : 'Enregistrement impossible. Réessaie dans un instant.',
          ),
        ),
      );
    }
  }

  /// « Passer » : rien n'est enregistré, mais l'étape est franchie — le
  /// parcours enchaîne sur la suite au lieu de reboucler.
  Future<void> _skip() async {
    await ref.read(firstRunControllerProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go(AppRoutes.home);
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
    // Sans session ouverte, l'onboarding précède la création de compte :
    // qui en a déjà un rejoint la connexion depuis ici.
    final authenticated =
        ref.watch(authControllerProvider) is AuthAuthenticated;

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
                  Expanded(
                    child: _buildBottomBlock(authenticated: authenticated),
                  ),
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
  ///
  /// La clé par étape REMET le défilement à zéro à chaque question : sans
  /// elle, une étape haute (l'objectif d'entraînement et ses huit cartes)
  /// s'ouvrait à la position léguée par la précédente, question coupée.
  Widget _buildBottomBlock({required bool authenticated}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: ValueKey('onboarding-etape-$_step'),
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
                onSkip: _skip,
                onLogin: authenticated
                    ? null
                    : () => context.go(AppRoutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return OnboardingQuestion(
      step: _step,
      carlysProfile: _carlysProfile,
      trainingGoal: _trainingGoal,
      goal: _goal,
      sex: _sex,
      birthDate: _birthDate,
      heightCm: _heightCm,
      heightTouched: _heightTouched,
      activityLevel: _activity,
      onCarlysProfile: (value) => setState(() => _carlysProfile = value),
      onTrainingGoal: (value) => setState(() => _trainingGoal = value),
      onGoal: (value) => setState(() => _goal = value),
      onSex: (value) => setState(() => _sex = value),
      onPickBirthDate: _pickBirthDate,
      onHeight: (value) => setState(() {
        _heightCm = value;
        _heightTouched = true;
      }),
      onActivity: (value) => setState(() => _activity = value),
    );
  }
}
