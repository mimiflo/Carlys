import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/environment/app_environment.dart';
import '../../../../design_system/design_system.dart';

/// Accueil provisoire de l'Étape 1.
///
/// Sert de vitrine au design system et confirme la configuration
/// d'environnement. Remplacé par le vrai tableau de bord (séances du jour,
/// progression) lors des tranches verticales du MVP.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Carlys')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Fondation prête', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Environnement : ${environment.flavor.name}\n'
              'API : ${environment.apiBaseUrl}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Design system', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            const AppButton(label: 'Action principale', onPressed: _noop),
            const SizedBox(height: AppSpacing.sm),
            const AppButton(
              label: 'Action secondaire',
              onPressed: _noop,
              variant: AppButtonVariant.secondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppButton(
              label: 'Chargement…',
              onPressed: _noop,
              isLoading: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppEmptyState(
              title: 'Aucune séance pour le moment',
              message:
                  'La bibliothèque d’exercices et les séances arrivent aux '
                  'Étapes 3 et 4.',
              icon: AppIcons.timer,
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}
