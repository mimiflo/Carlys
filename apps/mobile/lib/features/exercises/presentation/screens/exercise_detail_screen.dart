import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_library_controller.dart';

/// Fiche complète d'un exercice.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.idOrSlug, super.key});

  final String idOrSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(exerciseDetailProvider(idOrSlug));

    return Scaffold(
      appBar: AppBar(title: Text(detail.valueOrNull?.name ?? 'Exercice')),
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

class _ExerciseDetailBody extends StatelessWidget {
  const _ExerciseDetailBody({required this.exercise});

  final ExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppBadge(
              label: exercise.difficulty.label,
              variant: AppBadgeVariant.primary,
            ),
            AppBadge(label: exercise.kind.label),
            if (exercise.isPremium)
              const AppBadge(
                label: 'Premium',
                variant: AppBadgeVariant.accent,
                icon: AppIcons.premium,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(exercise.description, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        Text('Muscles travaillés', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final link in exercise.muscles)
              AppBadge(
                label: link.muscleGroup.name,
                variant: link.isPrimary
                    ? AppBadgeVariant.primary
                    : AppBadgeVariant.neutral,
              ),
          ],
        ),
        if (exercise.equipment.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Équipement', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final equipment in exercise.equipment)
                AppBadge(label: equipment.name),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Exécution', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, step) in exercise.instructions.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(step, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Exercice réservé aux membres Premium (décision prise par le serveur).
class _PremiumRequiredState extends StatelessWidget {
  const _PremiumRequiredState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.premium,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Exercice Premium',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cet exercice fait partie du catalogue Premium. '
              'Découvrez votre abonnement pour y accéder.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Voir mon abonnement',
              icon: AppIcons.premium,
              onPressed: () => context.push(AppRoutes.subscription),
            ),
          ],
        ),
      ),
    );
  }
}
