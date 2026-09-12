import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';
import '../../../onboarding/presentation/widgets/athlete_photo.dart';

/// Décor des écrans d'entrée, en deux variantes de la maquette :
/// la photographie d'athlète pour la connexion, le cœur de la marque pour
/// l'inscription — posé haut-droite, à moitié hors cadre, là où la maquette
/// mettait une sphère anonyme.
///
/// La photographie et le cœur ne se redessinent pas ici : [AthletePhoto]
/// et [HeartScene] (la scène du design system) sont réutilisés. Le CADRAGE
/// de la photographie, lui, est propre à cet écran ([_photoFade],
/// [_photoAlignment]) : celui de la page de marque suppose son cadre étroit
/// ancré à droite, pas le bandeau pleine largeur d'ici — le réutiliser
/// lierait silencieusement la connexion aux re-réglages de la bienvenue.
/// Aucune couche n'intercepte le toucher.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop.athlete({super.key}) : _heart = false;

  const AuthBackdrop.heart({super.key}) : _heart = true;

  final bool _heart;

  /// Géométrie de la maquette, en fractions d'écran : le cœur déborde du bord
  /// droit et s'arrête à mi-hauteur ; la photographie occupe le haut et
  /// s'éteint avant le formulaire.
  static const double _heartSize = 340;
  static const double _heartTopFactor = 0.02;
  static const double _heartRightOverflow = -120;
  static const double _heartOpacity = 0.5;
  static const List<double> _heartFade = [0.0, 0.16, 0.62, 0.92];

  /// Le formulaire commence vers 55 % de la hauteur : le fond doit être
  /// redevenu opaque là, sinon les champs se posent sur la photographie.
  static const List<double> _fadeStops = [0.0, 0.18, 0.42, 0.58];

  /// Cadrage de la photographie dans SON cadre d'ici (pleine largeur,
  /// 62 % de hauteur) — relevé sur les captures validées de la maquette.
  /// Le fondu gauche entre à 34 % de la largeur et devient plein à 59 % ;
  /// pleine largeur, le cliché n'est pas rogné horizontalement, le cadrage
  /// est donc neutre.
  static const List<double> _photoFade = [0.34, 0.59];
  static const double _photoAlignment = 0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final screen = Size(c.maxWidth, c.maxHeight);
          return Stack(
            children: [
              if (_heart)
                Positioned(
                  top: _heartTopFactor * screen.height,
                  right: _heartRightOverflow,
                  child: const AppSceneContainer(
                    size: _heartSize,
                    opacity: _heartOpacity,
                    verticalFadeStops: _heartFade,
                    child: HeartScene(),
                  ),
                )
              else
                Positioned(
                  top: 0,
                  right: 0,
                  width: screen.width,
                  height: screen.height * 0.62,
                  child: AthletePhoto(
                    screen: screen,
                    leftFadeStops: _photoFade,
                    alignmentX: _photoAlignment,
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
