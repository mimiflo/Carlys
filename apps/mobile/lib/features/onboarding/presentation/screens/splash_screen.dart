import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';

/// Écran de démarrage.
///
/// Étape 1 : affiche la marque puis navigue vers l'accueil. Les vérifications
/// réelles (session, mise à jour obligatoire, restauration de séance) s'y
/// grefferont lors des tranches suivantes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToHome());
  }

  Future<void> _navigateToHome() async {
    final delay = AppMotion.resolve(context, AppMotion.deliberate * 2);
    await Future<void>.delayed(delay);
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.workout,
                size: 64,
                color: theme.colorScheme.primary,
                semanticLabel: 'Logo Carlys',
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Carlys', style: theme.textTheme.displayLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Votre entraînement, partout.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
