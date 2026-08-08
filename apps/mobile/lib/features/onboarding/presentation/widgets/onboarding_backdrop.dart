import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';

/// Fond de l'onboarding : cœur ambient centré en haut, halo violet, puis
/// extinction vers le bas pour que la question et les réponses restent
/// lisibles par-dessus la scène.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({super.key});

  /// Géométrie de la maquette : scène de 360 posée à 24 du haut, à 42 %
  /// d'opacité, fondue en haut ET en bas.
  static const double _sceneSize = 360;
  static const double _sceneTop = 24;
  static const List<double> _sceneFade = [0.0, 0.22, 0.58, 0.88];

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: _sceneTop,
            left: 0,
            right: 0,
            child: Center(
              child: AppSceneContainer(
                size: _sceneSize,
                opacity: 0.42,
                verticalFadeStops: _sceneFade,
                child: HeartScene(),
              ),
            ),
          ),
          // Ordre de la maquette : l'extinction verticale d'abord, le halo
          // violet PAR-DESSUS (en CSS, la première couche listée est au-dessus).
          Positioned.fill(child: _BottomFade()),
          Positioned.fill(child: _PrimaryHalo()),
        ],
      ),
    );
  }
}

/// Halo violet posé haut-centre, comme le radial-gradient de la maquette.
class _PrimaryHalo extends StatelessWidget {
  const _PrimaryHalo();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.64),
          radius: 0.8,
          colors: [AppColors.primaryHalo, Colors.transparent],
          stops: [0.0, 0.66],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

/// Assombrissement vertical : le fond redevient totalement opaque aux
/// deux tiers de la hauteur, là où commence le bloc de texte.
class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.darkBackground.withValues(alpha: 0.5),
            AppColors.darkBackground.withValues(alpha: 0),
            AppColors.darkBackground.withValues(alpha: 0.6),
            AppColors.darkBackground,
            AppColors.darkBackground,
          ],
          stops: const [0.0, 0.18, 0.46, 0.62, 1.0],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
