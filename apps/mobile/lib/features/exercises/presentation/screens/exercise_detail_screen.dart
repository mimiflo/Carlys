import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_library_controller.dart';
import '../widgets/exercise_action_bar.dart';
import '../widgets/exercise_glass_button.dart';
import '../widgets/exercise_media_header.dart';
import '../widgets/exercise_muscles_card.dart';
import '../widgets/exercise_records_tiles.dart';
import '../widgets/exercise_steps_section.dart';

/// Fiche exercice (maquette 2e) : média placeholder plein cadre, records
/// réels, muscles sollicités, exécution numérotée et barre d'action basse.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.idOrSlug, super.key});

  final String idOrSlug;

  /// Décalage du bouton de retour sous la barre d'état (maquette).
  static const double _backButtonTop = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(exerciseDetailProvider(idOrSlug));

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          detail.when(
            loading: () => const AppLoadingIndicator(label: 'Chargement'),
            error: (error, _) => error is ForbiddenException
                ? const _PremiumRequiredState()
                : AppErrorState(
                    title: 'Exercice indisponible',
                    message: AppErrorState.retryConnectionMessage,
                    onRetry: () =>
                        ref.invalidate(exerciseDetailProvider(idOrSlug)),
                  ),
            data: (exercise) => _ExerciseDetailBody(exercise: exercise),
          ),
          // Le retour reste accessible quel que soit l'état de la fiche.
          Positioned(
            top: MediaQuery.paddingOf(context).top + _backButtonTop,
            left: AppSpacing.gutter,
            child: ExerciseGlassButton(
              icon: AppIcons.back,
              semanticLabel: 'Revenir à la bibliothèque',
              onPressed: () {
                final router = GoRouter.of(context);
                if (router.canPop()) {
                  router.pop();
                } else {
                  router.go(AppRoutes.exercises);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseDetailBody extends StatelessWidget {
  const _ExerciseDetailBody({required this.exercise});

  final ExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ExerciseMediaHeader(exercise: exercise),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.gapSection,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExerciseRecordsTiles(
                      exerciseId: exercise.id,
                      exerciseName: exercise.name,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ExerciseMusclesCard(muscles: exercise.muscles),
                    const SizedBox(height: AppSpacing.md),
                    ExerciseStepsSection(steps: exercise.instructions),
                  ],
                ),
              ),
            ],
          ),
        ),
        ExerciseActionBar(exercise: exercise),
      ],
    );
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
