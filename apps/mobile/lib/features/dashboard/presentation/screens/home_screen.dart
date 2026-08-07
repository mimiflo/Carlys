import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/synchronization/sync_lifecycle.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';

/// Accueil : séance (démarrer/reprendre), bibliothèque, historique, compte.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Démarre les déclencheurs de synchronisation (connectivité, périodique).
    ref.watch(syncLifecycleProvider).ensureStarted();

    final authState = ref.watch(authControllerProvider);
    final user = switch (authState) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final activeWorkout = ref.watch(activeWorkoutProvider).valueOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Carlys')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md +
                AppBottomBar.height +
                MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              user == null ? 'Bienvenue !' : 'Bienvenue, ${user.displayName} !',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (user != null)
              Row(
                children: [
                  Expanded(
                    child: Text(user.email, style: theme.textTheme.bodySmall),
                  ),
                  if (!user.emailVerified)
                    Tooltip(
                      message: 'Adresse e-mail non vérifiée',
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            Text('Entraînement', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            if (activeWorkout != null)
              AppButton(
                label: 'Reprendre la séance',
                icon: AppIcons.timer,
                isExpanded: true,
                onPressed: () => context.push(AppRoutes.activeWorkout),
              )
            else
              AppButton(
                label: 'Démarrer une séance',
                icon: AppIcons.add,
                isExpanded: true,
                onPressed: () async {
                  await ref.read(workoutActionsProvider).start();
                  if (context.mounted) {
                    await context.push(AppRoutes.activeWorkout);
                  }
                },
              ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Bibliothèque d’exercices',
              icon: AppIcons.workout,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => context.go(AppRoutes.exercises),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Historique',
              icon: AppIcons.history,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => context.push(AppRoutes.history),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Progression',
              icon: AppIcons.progress,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => context.go(AppRoutes.progress),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Nutrition',
              icon: AppIcons.nutrition,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => context.go(AppRoutes.nutrition),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Compte', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Abonnement',
              icon: AppIcons.premium,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => context.push(AppRoutes.subscription),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Appareils connectés',
              icon: Icons.devices,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => context.push(AppRoutes.sessions),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Réglages',
              icon: AppIcons.settings,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => context.push(AppRoutes.settings),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Se déconnecter',
              icon: Icons.logout,
              variant: AppButtonVariant.ghost,
              isExpanded: true,
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}
