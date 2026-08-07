import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_session/presentation/widgets/set_input_sheet.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_library_controller.dart';
import '../widgets/exercise_records_tiles.dart';

/// Fiche exercice (maquette 2e) : média (placeholder), muscles, records
/// personnels réels, technique numérotée, CTA « Ajouter à la séance ».
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.idOrSlug, super.key});

  final String idOrSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(exerciseDetailProvider(idOrSlug));

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(detail.valueOrNull?.name ?? 'Exercice'),
      ),
      body: SafeArea(
        child: detail.when(
          loading: () => const AppLoadingIndicator(label: 'Chargement'),
          error: (error, _) => error is ForbiddenException
              ? const _PremiumRequiredState()
              : AppErrorState(
                  title: 'Exercice indisponible',
                  message: 'Vérifiez votre connexion puis réessayez.',
                  onRetry: () =>
                      ref.invalidate(exerciseDetailProvider(idOrSlug)),
                ),
          data: (exercise) => _ExerciseDetailBody(exercise: exercise),
        ),
      ),
    );
  }
}

class _ExerciseDetailBody extends ConsumerWidget {
  const _ExerciseDetailBody({required this.exercise});

  final ExerciseDetail exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(personalRecordsProvider).valueOrNull;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              // Média : placeholder assumé — les vrais visuels arriveront
              // en assets, jamais générés ici.
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: AppRadius.cardMainAll,
                    border: Border.fromBorderSide(
                      BorderSide(color: AppColors.darkBorder),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        size: 44,
                        color: AppColors.darkTextTertiary,
                      ),
                      SizedBox(height: 8),
                      AppSectionLabel(
                        'Démonstration à venir',
                        color: AppColors.darkTextTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final link in exercise.muscles)
                    AppPill(
                      label: link.muscleGroup.name,
                      tone: link.isPrimary
                          ? AppPillTone.primary
                          : AppPillTone.neutral,
                    ),
                  AppPill(label: exercise.difficulty.label),
                  if (exercise.isPremium)
                    const AppPill(
                      label: 'PREMIUM',
                      tone: AppPillTone.accent,
                      mono: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                exercise.description,
                style: AppTypography.body
                    .copyWith(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: AppSpacing.gapSection),
              ExerciseRecordsTiles(
                exerciseName: exercise.name,
                records: records,
              ),
              const SizedBox(height: AppSpacing.gapSection),
              Text(
                'Technique',
                style: AppTypography.heading
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final (index, step) in exercise.instructions.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryCardSoft,
                          borderRadius: AppRadius.fullAll,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.primaryLightBorder),
                          ),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: AppTypography.labelMono
                              .copyWith(color: AppColors.primaryLight),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          step,
                          style: AppTypography.body
                              .copyWith(color: AppColors.darkTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              if (exercise.equipment.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final equipment in exercise.equipment)
                      AppPill(label: equipment.name),
                  ],
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.darkBackground,
                ),
                onPressed: () => _addToWorkout(context, ref),
                child: const Text('Ajouter à la séance'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Ajoute une série de cet exercice à la séance en cours — la démarre
  /// au besoin — puis ouvre la séance.
  Future<void> _addToWorkout(BuildContext context, WidgetRef ref) async {
    final input = await showSetInputSheet(context, exerciseName: exercise.name);
    if (input == null || !context.mounted) {
      return;
    }
    final actions = ref.read(workoutActionsProvider);
    final active = ref.read(activeWorkoutProvider).valueOrNull;
    final sessionId = active?.session.id ?? await actions.start();
    await actions.addSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        kind: input.kind,
        reps: input.reps,
        weightKg: input.weightKg,
        restSeconds: input.restSeconds,
      ),
    );
    if (context.mounted) {
      await context.push(AppRoutes.activeWorkout);
    }
  }
}

/// Exercice réservé aux membres Premium (décision prise par le serveur).
class _PremiumRequiredState extends StatelessWidget {
  const _PremiumRequiredState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              AppIcons.premium,
              size: 44,
              color: AppColors.accent,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Exercice Premium',
              style: AppTypography.title
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cet exercice fait partie du catalogue Premium. '
              'Votre abonnement donne accès à l’intégralité des mouvements.',
              textAlign: TextAlign.center,
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Voir mon abonnement',
              icon: AppIcons.premium,
              onPressed: () => GoRouter.of(context).push(
                AppRoutes.subscription,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
