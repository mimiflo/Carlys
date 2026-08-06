import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';

/// Écran de démarrage : déclenche la restauration de session.
/// Le routeur redirige dès que l'état de session est connu
/// (connexion ou accueil). Les vérifications futures (mise à jour
/// obligatoire, restauration de séance) se grefferont ici.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restore();
    });
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
