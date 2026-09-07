import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'heart_frame.dart';
import 'heart_specks.dart';
import 'scene3d.dart';
import 'scene_cadence.dart';

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
