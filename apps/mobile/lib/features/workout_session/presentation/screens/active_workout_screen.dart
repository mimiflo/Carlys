import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/workout_controllers.dart';
import '../widgets/active_workout_body.dart';

/// Séance active (maquette 2e) : plein écran sans barre d'onglets, halo
/// primaire en tête, saisie de série, minuteur de repos et clôture.
/// Toutes les écritures partent d'abord en base locale.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          const _PrimaryHalo(),
          SafeArea(
            // La barre basse gère elle-même l'encoche du bas.
            bottom: false,
            child: workout.when(
              loading: () => const AppLoadingIndicator(label: 'Chargement'),
              error: (_, __) => const AppErrorState(
                title: 'Séance indisponible',
                message: 'Impossible de lire la séance en cours.',
              ),
              data: (active) => active == null
                  ? const AppEmptyState(
                      title: 'Aucune séance en cours',
                      message: 'Démarrez une séance depuis l’accueil.',
                      icon: AppIcons.timer,
                    )
                  : ActiveWorkoutBody(workout: active),
            ),
          ),
        ],
      ),
    );
  }
}

/// Halo radial primaire de l'en-tête — atmosphère seule, jamais interactif.
class _PrimaryHalo extends StatelessWidget {
  const _PrimaryHalo();

  /// Géométrie de la maquette : ellipse de 34 % de hauteur ancrée en haut.
  static const double _height = 300;
  static const double _alpha = 0.22;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: _height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              stops: const [0, 0.7],
              colors: [
                AppColors.primary.withValues(alpha: _alpha),
                AppColors.primary.withValues(alpha: 0),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
