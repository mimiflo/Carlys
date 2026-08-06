import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';

/// Accueil provisoire (Étape 2) : compte connecté et accès aux appareils.
/// Remplacé par le vrai tableau de bord (séances, progression) à l'Étape 4+.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = switch (authState) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Carlys')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              user == null ? 'Bienvenue !' : 'Bienvenue, ${user.displayName} !',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (user != null) ...[
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
            ],
            const SizedBox(height: AppSpacing.lg),
            const AppEmptyState(
              title: 'Aucune séance pour le moment',
              message:
                  'La bibliothèque d’exercices et les séances arrivent aux '
                  'Étapes 3 et 4.',
              icon: AppIcons.timer,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Compte', style: theme.textTheme.titleLarge),
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
