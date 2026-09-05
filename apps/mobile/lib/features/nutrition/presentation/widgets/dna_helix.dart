import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/scenes/dna_animation.dart';
import '../../../../design_system/scenes/dna_scene.dart';
import '../../../../design_system/scenes/scene_scroll_activity.dart';

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
  /// Un tour complet, à la microseconde : la durée est DÉDUITE de la vitesse
  /// de rotation, sinon l'arrondi rouvre par la petite porte le saut de
  /// rebouclage qu'on vient de fermer.
  static final _cycle = Duration(
    microseconds: (DnaAnimation.cycleSeconds * 1000000).round(),
  );

  /// Cadence de rendu de la scène, comme le cœur (30 i/s) : au-delà, la
  /// rotation ne gagne rien de perceptible et chaque image coûte une hélice
  /// entière — sur un écran 120 Hz, c'est quatre fois moins de travail.
  static const double _framesPerSecond = 30;

  late final AnimationController _controller;
  bool _reduced = false;
  ValueListenable<bool>? _scrolling;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Préférence système : animation en boucle, ou pose figée à t = 0.
    _reduced = MediaQuery.disableAnimationsOf(context);
    // Et pause pendant le défilement de l'écran, comme le cœur : la scène
    // rend son budget au fil d'interface quand ça bouge.
    final scrolling = SceneScrollActivity.of(context);
    if (!identical(scrolling, _scrolling)) {
      _scrolling?.removeListener(_syncAnimation);
      _scrolling = scrolling;
      _scrolling?.addListener(_syncAnimation);
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) {
      return;
    }
    if (_reduced) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    if (_scrolling?.value ?? false) {
      // stop() conserve la phase ; repeat() repart d'où l'on s'était arrêté.
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _scrolling?.removeListener(_syncAnimation);
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
              builder: (context, _) {
                // Quantifié : le peintre ne repeint que quand le pas de
                // 1/30 s change (`shouldRepaint` compare le temps).
                final time = _controller.value * DnaAnimation.cycleSeconds;
                final quantized =
                    (time * _framesPerSecond).floor() / _framesPerSecond;
                return CustomPaint(painter: DnaScenePainter(time: quantized));
              },
            ),
          ),
        ),
      ),
    );
  }
}
