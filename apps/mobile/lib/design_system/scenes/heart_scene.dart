import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'heart_engine.dart';
import 'heart_frame.dart';
import 'heart_specks.dart';
import 'scene3d.dart';
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

/// Rendu d'une image du cœur.
///
/// Public comme celui de l'hélice, et pour la même raison : certains défauts
/// n'existent qu'en mouvement (une particule qui se téléporte au rebouclage,
/// une nuée qui apparaît d'un coup). La planche de contrôle
/// `tool/screenshots/heart_frames_test.dart` rend la scène à des instants
/// choisis, ce qu'aucune capture d'écran ne saurait montrer.
class HeartScenePainter extends CustomPainter {
  HeartScenePainter({
    required this.seconds,
    required this.hero,
    this.still = false,
    this.cadence,
    this.frame,
  });

  final double seconds;
  final bool hero;

  /// Pose figée (réduction d'animations) : diastole franche, sans contraction.
  final bool still;

  /// Reçoit le coût du calcul quand il a lieu ICI (repli synchrone) — c'est
  /// lui qui décide de la cadence. Absent sur la planche de contrôle.
  final SceneCadence? cadence;

  /// Image préparée par l'isolate. Null, ou taille/mode dépassés : le
  /// peintre recalcule en synchrone — même fonction, mêmes pixels. C'est le
  /// chemin des tests, de la planche de contrôle et de la première image.
  final HeartFrame? frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final HeartFrame prepared;
    final cached = frame;
    if (cached != null &&
        cached.hero == hero &&
        cached.width == size.width &&
        cached.height == size.height) {
      prepared = cached;
    } else {
      final stopwatch = Stopwatch()..start();
      prepared = computeHeartFrame(
        HeartFrameRequest(
          seconds: seconds,
          hero: hero,
          still: still,
          width: size.width,
          height: size.height,
        ),
      );
      cadence?.reportPaintCost(stopwatch.elapsed);
    }
    _draw(canvas, size, prepared);
  }

  void _draw(Canvas canvas, Size size, HeartFrame frame) {
    // Halo, particules et poussières se recalent sur l'instant de l'IMAGE :
    // ils restent solidaires du maillage qu'ils habillent, même si le temps
    // du widget a avancé d'un pas depuis.
    final camera = heartCamera();
    final rotation = EulerRotation(
      0.16,
      -0.42 + math.sin(frame.seconds * 0.22) * 0.28,
      0.18,
    );

    // --- Particules passant DERRIÈRE la masse ---
    HeartSpecks.paint(
      canvas,
      size,
      camera,
      seconds: frame.seconds,
      hero: hero,
      front: false,
    );

    // --- Halo interne, sous le maillage ---
    _paintHalo(canvas, size, camera, frame.bob, frame.beat);

    // --- Voile interne : silhouette additive qui donne sa densité au volume
    // (le maillage `core` en BackSide de la maquette). ---
    if (frame.coreIndices.isNotEmpty) {
      canvas.drawVertices(
        ui.Vertices.raw(
          ui.VertexMode.triangles,
          frame.wide,
          colors: frame.coreColors,
          indices: frame.coreIndices,
        ),
        BlendMode.plus,
        Paint(),
      );
    }

    if (frame.indices.isNotEmpty) {
      canvas.drawVertices(
        ui.Vertices.raw(
          ui.VertexMode.triangles,
          frame.screen,
          colors: frame.colors,
          indices: frame.indices,
        ),
        BlendMode.srcOver,
        Paint(),
      );
    }

    _paintParticles(canvas, size, camera, rotation, frame);

    // --- Particules passant DEVANT la masse ---
    HeartSpecks.paint(
      canvas,
      size,
      camera,
      seconds: frame.seconds,
      hero: hero,
      front: true,
    );
  }

  /// Lueur de pouls : la sphère de Fresnel de la maquette, transposée en
  /// dégradé radial dont le profil suit exactement `pow(1 - |N·V|, 2.6)` —
  /// donc sombre au centre et lumineuse sur le pourtour, comme un liseré.
  void _paintHalo(
    Canvas canvas,
    Size size,
    SceneCamera camera,
    double bob,
    double beat,
  ) {
    final center = camera.project(0, bob, 0, size.width, size.height);
    final unit = camera.pixelsPerUnit(camera.z, size.height);
    final glow = heartViolet.lerpTo(heartAccent, beat * 0.30);
    final intensity = (hero ? 0.20 : 0.10) + beat * (hero ? 0.30 : 0.16);
    final color = Color.fromARGB(
      255,
      (linearToSrgb(glow.r.clamp(0.0, 1.0)) * 255).round(),
      (linearToSrgb(glow.g.clamp(0.0, 1.0)) * 255).round(),
      (linearToSrgb(glow.b.clamp(0.0, 1.0)) * 255).round(),
    );

    // Halo diffus de fond (sphère 1.8, face interne, opacité .05).
    final haloRadius = unit * 1.8 * (1 + beat * 0.09);
    canvas.drawCircle(
      Offset(center.sx, center.sy),
      haloRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(center.sx, center.sy),
          haloRadius,
          [
            color.withValues(alpha: hero ? 0.09 : 0.05),
            color.withValues(alpha: 0),
          ],
          const [0.55, 1.0],
        ),
    );

    // Liseré de Fresnel (sphère 1.95, additive).
    final rimRadius = unit * 1.95 * (1 + beat * 0.06);
    const steps = 8;
    final stops = <double>[];
    final colors = <Color>[];
    for (var i = 0; i <= steps; i++) {
      final d = i / steps;
      final cosTheta = math.sqrt(math.max(0.0, 1 - d * d));
      final fresnel = math.pow(1 - cosTheta, 2.6).toDouble();
      stops.add(d);
      colors.add(
        color.withValues(alpha: (fresnel * intensity).clamp(0.0, 1.0)),
      );
    }

    canvas.drawCircle(
      Offset(center.sx, center.sy),
      rimRadius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          Offset(center.sx, center.sy),
          rimRadius,
          colors,
          stops,
        ),
    );
  }

  /// Flux sanguin : points déterministes en orbite (aucun aléatoire, le rendu
  /// doit être reproductible d'une image à l'autre et d'un test à l'autre).
  void _paintParticles(
    Canvas canvas,
    Size size,
    SceneCamera camera,
    EulerRotation rotation,
    HeartFrame frame,
  ) {
    const count = 140;
    final seconds = frame.seconds;
    final beat = frame.beat;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..color = const Color(0xFFD6D6FF).withValues(alpha: hero ? 0.5 : 0.26);

    for (var i = 0; i < count; i++) {
      final h1 = sceneNoise(i * 1.0);
      final h2 = sceneNoise(i * 1.0 + 97);
      final h3 = sceneNoise(i * 1.0 + 211);
      final h4 = sceneNoise(i * 1.0 + 331);

      final r = (2.5 + h1 * 1.7) * (1 + beat * 0.08);
      final angle = h2 * math.pi * 2 + seconds * (0.15 + h4 * 0.4) * 0.4;
      final y =
          (h3 - 0.5) * 3.4 + math.sin(seconds * 0.5 + h2 * math.pi * 2) * 0.16;

      final lx = math.cos(angle) * r;
      final lz = math.sin(angle) * r;

      final wx = rotation.rotX(lx, y, lz);
      final wy = rotation.rotY(lx, y, lz) + frame.bob;
      final wz = rotation.rotZ(lx, y, lz);

      final p = camera.project(wx, wy, wz, size.width, size.height);
      if (p.viewZ >= 0) {
        continue;
      }
      final diameter =
          (hero ? 0.045 : 0.032) * (size.height * 0.5) / p.viewZ.abs();
      canvas.drawCircle(
        Offset(p.sx, p.sy),
        math.max(diameter * 0.5, 0.35),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HeartScenePainter old) =>
      old.seconds != seconds ||
      old.hero != hero ||
      old.still != still ||
      !identical(old.frame, frame);
}
