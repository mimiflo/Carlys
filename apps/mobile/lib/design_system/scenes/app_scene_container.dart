import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

/// Socle des scènes 3D (cœur, hélice) : applique les règles communes du
/// handoff — extinction radiale du canvas, fondu linéaire selon la place à
/// l'écran, et gradient d'assombrissement sous les textes.
///
/// Phase 4 : la scène animée remplace [child] ; le conteneur et ses masques
/// ne changent pas.
class AppSceneContainer extends StatelessWidget {
  const AppSceneContainer({
    required this.size,
    required this.child,
    this.opacity = 1,
    this.verticalFadeStops,
    super.key,
  });

  final double size;
  final Widget child;
  final double opacity;

  /// Points du fondu vertical (transparent → opaque → transparent),
  /// ex. `[0.0, 0.18, 0.56, 0.90]` pour l'accueil.
  final List<double>? verticalFadeStops;

  @override
  Widget build(BuildContext context) {
    Widget scene = ShaderMask(
      // Extinction radiale : jamais d'arête droite au bord du canvas.
      shaderCallback: (bounds) => const RadialGradient(
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.58, 0.96],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: child,
    );

    final stops = verticalFadeStops;
    if (stops != null && stops.length == 4) {
      scene = ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: stops,
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: scene,
      );
    }

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: SizedBox(width: size, height: size, child: scene),
      ),
    );
  }
}

/// Gradient de lisibilité à poser PAR-DESSUS une scène quand du texte vit
/// en colonne de gauche (latéral à 100°) ou en dessous (vertical).
class AppSceneScrim extends StatelessWidget {
  const AppSceneScrim.lateral({super.key}) : _lateral = true;
  const AppSceneScrim.vertical({super.key}) : _lateral = false;

  final bool _lateral;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _lateral
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.darkBackground,
                    Color(0xB306060C),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.34, 0.72],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x8006060C),
                    AppColors.darkBackground,
                  ],
                  stops: [0.3, 0.75, 1.0],
                ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Halo violet statique — silhouette d'attente des scènes 3D (le rendu
/// animé arrive en Phase 4 ; ce halo reste le repli reduce-motion).
class AppSceneHalo extends StatelessWidget {
  const AppSceneHalo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0x665B5BF6),
            Color(0x2E5B5BF6),
            Colors.transparent,
          ],
          stops: [0.0, 0.45, 0.85],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
