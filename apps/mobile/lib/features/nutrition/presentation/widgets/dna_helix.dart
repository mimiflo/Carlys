import 'package:flutter/material.dart';

import '../../../../design_system/scenes/dna_scene.dart';

/// Double hélice d'ADN — portage fidèle de `dna-helix.js` (mode « hero »).
///
/// Deux brins en TUBE lustré (violet `0x9B30FF` et `0xC88BFF`, déphasés de π)
/// reliés par 26 barreaux faits de deux demi-cylindres avec un jeu central, un
/// sur trois en orange. Rotation continue 0,22 rad/s, respiration globale ±3 % à
/// 0,65 Hz et écartement individuel des paires. Tout le rendu vit dans
/// [DnaScenePainter] ; ce widget ne fait que piloter le temps.
///
/// [height] est la hauteur du canevas : c'est elle qui fixe l'échelle de la
/// scène (champ de 30° depuis z = 13, comme la maquette).
///
/// Purement décorative : pose figée à t = 0 si la réduction d'animations
/// système est active.
class DnaHelix extends StatefulWidget {
  const DnaHelix({this.height = 140, super.key});

  final double height;

  @override
  State<DnaHelix> createState() => _DnaHelixState();
}

class _DnaHelixState extends State<DnaHelix>
    with SingleTickerProviderStateMixin {
  /// Un tour complet à 0,22 rad/s : ~28,6 s par cycle.
  static const _cycle = Duration(milliseconds: 28560);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Préférence système : animation en boucle, ou pose figée à t = 0.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Animation décorative : double hélice d’ADN',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: DnaScenePainter(
                  time: _controller.value * _cycle.inMilliseconds / 1000.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
