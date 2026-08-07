import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../nutrition/domain/entities/nutrition.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../widgets/onboarding_option_card.dart';

/// Onboarding (maquette 2i) : 4 étapes qui remplissent le profil
/// métabolique réel (objectif, sexe, naissance/taille, activité).
/// « Passer » est toujours possible — le profil se complète aussi depuis
/// l'onglet Nutrition.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  NutritionGoal? _goal;
  BiologicalSex? _sex;
  DateTime? _birthDate;
  double _heightCm = 175;
  bool _heightTouched = false;
  ActivityLevel? _activity;
  bool _saving = false;

  static const _stepCount = 4;

  bool get _stepComplete => switch (_step) {
        0 => _goal != null,
        1 => _sex != null,
        2 => _birthDate != null && _heightTouched,
        _ => _activity != null,
      };

  Future<void> _next() async {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      return;
    }
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        context.go(AppRoutes.home);
      }
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
        () => _birthDate = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          const Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: AppSceneContainer(
                size: 360,
                opacity: 0.42,
                verticalFadeStops: [0.0, 0.22, 0.58, 0.88],
                child: AppSceneHalo(),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SegmentsBar(current: _step, total: _stepCount),
                  const SizedBox(height: AppSpacing.gapSection),
                  Expanded(child: _buildStep()),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.darkBackground,
                      disabledBackgroundColor: AppColors.darkSurfaceAlt,
                      disabledForegroundColor: AppColors.darkTextTertiary,
                    ),
                    onPressed: _stepComplete && !_saving ? _next : null,
                    child: Text(
                      _step < _stepCount - 1 ? 'Continuer' : 'Terminer',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: Text(
                        'Passer',
                        style: AppTypography.body
                            .copyWith(color: AppColors.darkTextTertiary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _StepScaffold(
          label: 'Ton objectif',
          question: 'Qu’est-ce qu’on\nconstruit ensemble ?',
          subtitle: 'On calibre tes charges, ton volume et tes macros '
              'à partir de ça.',
          options: [
            for (final goal in NutritionGoal.values)
              OnboardingOptionCard(
                title: goal.label,
                subtitle: switch (goal) {
                  NutritionGoal.gainMuscle => 'Surplus léger, volume élevé',
                  NutritionGoal.loseWeight => 'Déficit, maîtrise, cardio',
                  NutritionGoal.maintain => 'Régularité avant tout',
                },
                icon: switch (goal) {
                  NutritionGoal.gainMuscle => AppIcons.workout,
                  NutritionGoal.loseWeight => Icons.local_fire_department,
                  NutritionGoal.maintain => Icons.self_improvement,
                },
                selected: _goal == goal,
                onTap: () => setState(() => _goal = goal),
              ),
          ],
        ),
      1 => _StepScaffold(
          label: 'Ton profil',
          question: 'Pour calibrer\nton métabolisme',
          subtitle: 'La formule de Mifflin-St Jeor dépend du sexe biologique.',
          options: [
            for (final sex in BiologicalSex.values)
              OnboardingOptionCard(
                title: sex.label,
                selected: _sex == sex,
                onTap: () => setState(() => _sex = sex),
              ),
          ],
        ),
      2 => _StepScaffold(
          label: 'Tes mesures',
          question: 'Naissance\net taille',
          subtitle: 'L’âge et la taille entrent dans le calcul quotidien.',
          options: [
            OnboardingOptionCard(
              title: _birthDate == null
                  ? 'Choisir ma date de naissance'
                  : 'Né(e) le ${_formatDate(_birthDate!)}',
              icon: Icons.cake_outlined,
              selected: _birthDate != null,
              onTap: _pickBirthDate,
            ),
            _HeightCard(
              heightCm: _heightCm,
              touched: _heightTouched,
              onChanged: (value) => setState(() {
                _heightCm = value;
                _heightTouched = true;
              }),
            ),
          ],
        ),
      _ => _StepScaffold(
          label: 'Ton rythme',
          question: 'À quelle fréquence\nbouges-tu ?',
          subtitle: 'Ta dépense d’activité s’ajoute à ton métabolisme de base.',
          options: [
            for (final level in ActivityLevel.values)
              OnboardingOptionCard(
                title: level.label,
                subtitle: level.description,
                selected: _activity == level,
                onTap: () => setState(() => _activity = level),
              ),
          ],
        ),
    };
  }

  static String _formatDate(DateTime date) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(date.day)}/${pad(date.month)}/${date.year}';
  }
}

class _SegmentsBar extends StatelessWidget {
  const _SegmentsBar({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Étape ${current + 1} sur $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= current ? AppColors.accent : AppColors.gaugeTrack,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.label,
    required this.question,
    required this.subtitle,
    required this.options,
  });

  final String label;
  final String question;
  final String subtitle;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AppSectionLabel(label),
        const SizedBox(height: 10),
        Text(
          question,
          style:
              AppTypography.display.copyWith(color: AppColors.darkTextPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style:
              AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
        ),
        const SizedBox(height: AppSpacing.gutter),
        for (final option in options) ...[
          option,
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _HeightCard extends StatelessWidget {
  const _HeightCard({
    required this.heightCm,
    required this.touched,
    required this.onChanged,
  });

  final double heightCm;
  final bool touched;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.all(
          color: touched ? AppColors.primaryLight : AppColors.darkBorder,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.height_rounded,
            size: 22,
            color: AppColors.darkTextTertiary,
          ),
          const SizedBox(width: AppSpacing.gapRow),
          Expanded(
            child: Text(
              'Taille',
              style: AppTypography.subheading
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
          ),
          IconButton(
            tooltip: 'Réduire',
            onPressed: () => onChanged(heightCm - 1),
            icon: const Icon(
              Icons.remove_rounded,
              color: AppColors.darkTextSecondary,
            ),
          ),
          Text(
            '${heightCm.round()} cm',
            style: AppTypography.metricM
                .copyWith(color: AppColors.darkTextPrimary),
          ),
          IconButton(
            tooltip: 'Augmenter',
            onPressed: () => onChanged(heightCm + 1),
            icon: const Icon(
              Icons.add_rounded,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
