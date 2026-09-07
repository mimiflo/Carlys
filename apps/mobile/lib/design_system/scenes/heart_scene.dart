import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'heart_engine.dart';
import 'heart_frame.dart';
import 'heart_scene_painter.dart';
import 'scene_cadence.dart';
import 'scene_scroll_activity.dart';

/// Cœur battant de la refonte — portage fidèle de `pulse-heart.js`.
///
/// Même géométrie (profil cardiaque révolutionné, 1,05 × 1,02 × 0,86), même
/// matériau (violet auto-éclairé, rugosité 0,42, métallicité 0,3), mêmes
/// lumières et même tone mapping ACES que la maquette : le rendu doit être
/// indiscernable de la référence WebGL.
///
/// Le battement est calé sur 57 bpm (fréquence de repos d'un athlète).
///
/// Le CALCUL de chaque image (déformation, projection, tri, éclairage de
/// ~12 000 sommets — voir `heart_frame.dart`) vit dans un isolate dédié
/// (`heart_engine.dart`) : le fil d'interface ne fait plus que dessiner des
/// tampons prêts, le défilement ne partage plus son budget avec le cœur.
class HeartScene extends StatefulWidget {
  const HeartScene({this.hero = false, super.key});

  /// Mode « hero » : plus opaque et plus lumineux que le mode d'ambiance.
  final bool hero;

  @override
  State<HeartScene> createState() => _HeartSceneState();
}

class _HeartSceneState extends State<HeartScene>
    with SingleTickerProviderStateMixin {
  /// Cadence de rendu de la scène, indépendante de celle de l'écran :
  /// 30 i/s quand l'appareil suit, 20 puis 15 quand il peine — mesuré sur
  /// le coût réel de calcul d'une image. Même déporté sur un autre cœur du
  /// processeur, un maillage cher reste cher : la cadence préserve la
  /// batterie et laisse l'isolate respirer.
  final SceneCadence _cadence = SceneCadence();

  /// Le calcul du maillage vit dans un isolate : à chaque pas de cadence, le
  /// widget envoie l'instant à rendre, l'isolate répond par des tampons
  /// prêts à dessiner ([_frame]).
  final HeartEngine _engine = HeartEngine();

  /// Temps ÉCOULÉ, jamais ramené à zéro.
  ///
  /// Un `AnimationController` rebouclé sur trente secondes rendait le temps
  /// discontinu, et rien dans cette scène n'a de période qui divise le tour :
  /// la rotation (0,22 rad/s), le ballant (0,45) et le battement (57 bpm,
  /// soit 28,5 battements) sautaient donc tous ensemble à chaque tour.
  /// Relevé sur la planche de contrôle avant correction : 6 106 pixels
  /// changeaient d'un coup entre la dernière image d'un tour et la première du
  /// suivant, dont 1 974 sur la silhouette même du cœur. Un temps monotone
  /// supprime la question au lieu d'accorder les fréquences une à une.
  late final Ticker _ticker = createTicker(_onTick);
  double _seconds = 0;

  /// Temps accumulé AVANT la pause en cours : le Ticker repart de zéro à
  /// chaque start(), le temps de scène, lui, ne revient jamais en arrière.
  double _accumulated = 0;
  bool _reduced = false;
  ValueListenable<bool>? _scrolling;

  /// Dernière image livrée par l'isolate ; null tant qu'aucune n'est prête
  /// (toute première image, tests, plateforme sans isolates) — le peintre
  /// calcule alors lui-même, en synchrone.
  HeartFrame? _frame;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _engine.latest.addListener(_onFrame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La boucle ne doit JAMAIS tourner sous réduction d'animations : sinon la
    // scène empêche toute stabilisation (accessibilité, et tests de widgets).
    _reduced = MediaQuery.disableAnimationsOf(context);
    // Et elle se FIGE pendant le défilement de l'écran englobant : même
    // calculée ailleurs, chaque image finit dessinée sur le fil d'interface —
    // et une scène immobile pendant le geste, c'est aussi de la batterie.
    final scrolling = SceneScrollActivity.of(context);
    if (!identical(scrolling, _scrolling)) {
      _scrolling?.removeListener(_syncTicker);
      _scrolling = scrolling;
      _scrolling?.addListener(_syncTicker);
    }
    _syncTicker();
  }

  void _syncTicker() {
    if (!mounted) {
      return;
    }
    final paused = _reduced || (_scrolling?.value ?? false);
    if (paused) {
      if (_ticker.isActive) {
        _accumulated = _seconds;
        _ticker.stop();
      }
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    // Quantifié au pas de la cadence courante : au-delà de 30 i/s le
    // battement ne gagne rien de perceptible, et chaque image coûte un
    // maillage entier.
    final fps = _cadence.framesPerSecond;
    final seconds =
        _accumulated + (elapsed.inMicroseconds * fps / 1000000).floor() / fps;
    if (seconds == _seconds) {
      return;
    }
    _seconds = seconds;
    _requestFrame();
    // Tant que l'isolate n'a rien livré, c'est le temps qui pousse le repli
    // synchrone du peintre ; ensuite, c'est l'ARRIVÉE des images qui repeint —
    // repeindre ici redessinerait la même image pour rien.
    if (_frame == null) {
      setState(() {});
    }
  }

  void _onFrame() {
    final frame = _engine.latest.value;
    if (frame == null || !mounted) {
      return;
    }
    // Le coût mesuré DANS l'isolate pilote la cadence.
    _cadence.reportPaintCost(Duration(microseconds: frame.computeMicros));
    setState(() => _frame = frame);
  }

  void _requestFrame() {
    if (_reduced || _size.isEmpty || !_size.isFinite) {
      return;
    }
    _engine.request(
      HeartFrameRequest(
        seconds: _seconds,
        hero: widget.hero,
        still: false,
        width: _size.width,
        height: _size.height,
      ),
    );
  }

  @override
  void dispose() {
    _scrolling?.removeListener(_syncTicker);
    _engine.latest.removeListener(_onFrame);
    _engine.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Réduction d'animations : on fige le cœur sur une pose de diastole.
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // L'isolate a besoin de la taille pour projeter : on la relève ici,
        // et le peintre couvre en synchrone le temps d'une nouvelle image.
        final size = constraints.biggest;
        if (size != _size) {
          _size = size;
          _requestFrame();
        }
        return CustomPaint(
          painter: HeartScenePainter(
            seconds: still ? 0 : _seconds,
            hero: widget.hero,
            still: still,
            cadence: _cadence,
            frame: still ? null : _frame,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
