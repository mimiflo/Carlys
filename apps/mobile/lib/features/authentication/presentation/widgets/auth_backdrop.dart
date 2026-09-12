import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';

/// Décor commun des écrans d'entrée : le cœur de la marque posé haut-droite,
/// à moitié hors cadre — là où la maquette mettait une sphère anonyme — sur
/// fond d'extinction verticale et de halo violet.
///
/// La connexion et l'inscription partagent ce décor à l'identique (choix
/// produit : la photographie d'athlète de la maquette de connexion a été
/// écartée au profit du cœur). Le cœur ne se redessine pas ici :
/// [HeartScene] est la scène du design system, réutilisée telle quelle.
/// Aucune couche n'intercepte le toucher.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop.heart({super.key});

  /// Géométrie de la maquette, en fractions d'écran : le cœur déborde du bord
  /// droit et s'arrête à mi-hauteur.
  static const double _heartSize = 340;
  static const double _heartTopFactor = 0.02;
  static const double _heartRightOverflow = -120;
  static const double _heartOpacity = 0.5;
  static const List<double> _heartFade = [0.0, 0.16, 0.62, 0.92];

  /// Le formulaire commence vers 55 % de la hauteur : le fond doit être
  /// redevenu opaque là, sinon les champs se posent sur le décor.
  static const List<double> _fadeStops = [0.0, 0.18, 0.42, 0.58];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final screen = Size(c.maxWidth, c.maxHeight);
          return Stack(
            children: [
              Positioned(
                top: _heartTopFactor * screen.height,
                right: _heartRightOverflow,
                child: const AppSceneContainer(
                  size: _heartSize,
                  opacity: _heartOpacity,
                  verticalFadeStops: _heartFade,
                  child: HeartScene(),
                ),
              ),
              // Extinction verticale : le décor vit en haut, le formulaire
              // au calme sur le fond — même logique que l'onboarding.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.darkBackground.withValues(alpha: 0.35),
                        AppColors.darkBackground.withValues(alpha: 0),
                        AppColors.darkBackground.withValues(alpha: 0.7),
                        AppColors.darkBackground,
                      ],
                      stops: _fadeStops,
                    ),
                  ),
                ),
              ),
              // Halo violet haut : la couleur de marque enveloppe le décor.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.6, -0.75),
                      radius: 0.9,
                      colors: [AppColors.primaryHalo, Colors.transparent],
                      stops: [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
