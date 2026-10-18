import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/scenes/dna_animation.dart';
import '../../../../design_system/scenes/dna_scene.dart';
import '../../../../design_system/scenes/scene_clock.dart';
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

class _DnaHelixState extends State<DnaHelix> {
  /// Cadence de rendu de la scène, comme le cœur (30 i/s) : au-delà, la
  /// rotation ne gagne rien de perceptible et chaque image coûte une hélice
  /// entière — sur un écran 120 Hz, c'est quatre fois moins de travail.
  ///
  /// L'horloge ne réveille la scène qu'à chaque pas : un `AnimationController`
  /// demandait une image à chaque battement d'écran, même quand le pas de
  /// 1/30 s n'avait pas changé (`scene_frame_requests_test.dart`).
  static const double _framesPerSecond = 30;

  late final SceneClock _clock = SceneClock(
    framesPerSecond: () => _framesPerSecond,
    onStep: (_) {
      if (mounted) setState(() {});
    },
  );
  bool _reduced = false;
  bool _hidden = false;
  ValueListenable<bool>? _scrolling;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Préférence système : animation en boucle, ou pose figée à t = 0.
    _reduced = MediaQuery.disableAnimationsOf(context);
    // Hors de l'écran (onglet caché, route recouverte), rien ne tourne.
    _hidden = !TickerMode.valuesOf(context).enabled;
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
    // stop() conserve la phase ; start() repart d'où l'on s'était arrêté.
    if (_reduced || _hidden || (_scrolling?.value ?? false)) {
      _clock.stop();
    } else {
      _clock.start();
    }
  }

  @override
  void dispose() {
    _scrolling?.removeListener(_syncAnimation);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Le temps de scène, rebouclé sur un tour complet : la rotation ne
    // saute pas, `DnaAnimation.cycleSeconds` est déduit de sa vitesse.
    final time = _reduced ? 0.0 : _clock.seconds % DnaAnimation.cycleSeconds;
    return Semantics(
      label: 'Animation décorative : double hélice d’ADN',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(painter: DnaScenePainter(time: time)),
          ),
        ),
      ),
    );
  }
}
