import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../motion/app_motion.dart';
import 'scene_math.dart';

/// Cœur battant (handoff/animations-3d.md + pulse-heart.js).
///
/// Cardioïde 2D (sin³/cosinus composés) tournée autour de Y et gonflée en
/// Z par un profil elliptique — un cœur PLEIN, pas une icône extrudée.
/// Le maillage se génère une fois à l'initState ; seul le buffer de
/// positions/couleurs est réécrit par frame (drawVertices).
///
/// Battement 57 bpm : somme de deux gaussiennes (systole marquée, rebond
/// diastolique), contraction −8,5 % sur les rayons, −5,5 % en hauteur.
/// Réduction d'animations : pose statique au pic de systole.
class HeartScene extends StatefulWidget {
  const HeartScene({this.hero = false, super.key});

  final bool hero;

  @override
  State<HeartScene> createState() => _HeartSceneState();
}

class _HeartSceneState extends State<HeartScene>
    with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 21053); // 20 battements/tour

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.resolve(context, _period) == Duration.zero;
    if (reduced) {
      _controller.stop();
      _controller.value = 0.004; // pic de systole du premier battement
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _HeartPainter(
            time: _controller.value * _period.inMilliseconds / 1000.0,
            hero: widget.hero,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Maillage partagé entre toutes les instances (généré une seule fois).
class _HeartMesh {
  _HeartMesh._();

  static final _HeartMesh instance = _HeartMesh._();

  static const rings = 40;
  static const segments = 56;

  // Position de repos (x, y, z) et normale par sommet.
  late final Float32List rest = _buildRest();
  late final Float32List normals = _buildNormals();
  late final Uint16List triangles = _buildTriangles();

  /// Profil du cœur : la courbe classique x=16sin³t, y=13cost−5cos2t−…
  /// donne le rayon et la hauteur de chaque anneau.
  static (double, double) _profile(double t) {
    final radius = math.pow(math.sin(t), 3).toDouble() * 1.0;
    final height = (13 * math.cos(t) -
            5 * math.cos(2 * t) -
            2 * math.cos(3 * t) -
            math.cos(4 * t)) /
        16.0;
    return (radius, height);
  }

  Float32List _buildRest() {
    final data = Float32List(rings * segments * 3);
    var cursor = 0;
    for (var ring = 0; ring < rings; ring++) {
      final t = math.pi * ring / (rings - 1);
      final (radius, height) = _profile(t);
      for (var seg = 0; seg < segments; seg++) {
        final phi = 2 * math.pi * seg / segments;
        // Gonflement elliptique en Z : le cœur est plein, pas plat.
        data[cursor++] = radius * math.cos(phi);
        data[cursor++] = height;
        data[cursor++] = radius * math.sin(phi) * 0.72;
      }
    }
    return data;
  }

  Float32List _buildNormals() {
    // Normales par différences finies sur la grille (anneau, segment).
    final normals = Float32List(rings * segments * 3);
    for (var ring = 0; ring < rings; ring++) {
      for (var seg = 0; seg < segments; seg++) {
        final i = (ring * segments + seg) * 3;
        final ringNext = (ring + 1).clamp(0, rings - 1) * segments;
        final ringPrev = (ring - 1).clamp(0, rings - 1) * segments;
        final a = (ringNext + seg) * 3;
        final b = (ringPrev + seg) * 3;
        final c = (ring * segments + (seg + 1) % segments) * 3;
        final d = (ring * segments + (seg - 1 + segments) % segments) * 3;

        final ux = rest[a] - rest[b];
        final uy = rest[a + 1] - rest[b + 1];
        final uz = rest[a + 2] - rest[b + 2];
        final vx = rest[c] - rest[d];
        final vy = rest[c + 1] - rest[d + 1];
        final vz = rest[c + 2] - rest[d + 2];

        var nx = uy * vz - uz * vy;
        var ny = uz * vx - ux * vz;
        var nz = ux * vy - uy * vx;
        final length = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (length > 1e-9) {
          nx /= length;
          ny /= length;
          nz /= length;
        }
        // Oriente vers l'extérieur (le centre est en 0,±,0).
        final outward = nx * rest[i] + nz * rest[i + 2];
        final sign = outward >= 0 ? 1.0 : -1.0;
        normals[i] = nx * sign;
        normals[i + 1] = ny * sign;
        normals[i + 2] = nz * sign;
      }
    }
    return normals;
  }

  Uint16List _buildTriangles() {
    final indices = Uint16List((rings - 1) * segments * 6);
    var cursor = 0;
    for (var ring = 0; ring < rings - 1; ring++) {
      for (var seg = 0; seg < segments; seg++) {
        final a = ring * segments + seg;
        final b = ring * segments + (seg + 1) % segments;
        final c = a + segments;
        final d = b + segments;
        indices[cursor++] = a;
        indices[cursor++] = b;
        indices[cursor++] = c;
        indices[cursor++] = b;
        indices[cursor++] = d;
        indices[cursor++] = c;
      }
    }
    return indices;
  }
}

class _HeartPainter extends CustomPainter {
  _HeartPainter({required this.time, required this.hero});

  final double time;
  final bool hero;

  /// Battement à deux temps : gaussiennes en phase 0,08 (systole) et
  /// 0,30 (rebond diastolique) de la période ~1,05 s (57 bpm).
  static double beatOf(double time) {
    final phase = (time / 1.053) % 1.0;
    double gauss(double centre, double width) {
      final delta = phase - centre;
      return math.exp(-delta * delta / (2 * width * width));
    }

    return (gauss(0.08, 0.045) + 0.55 * gauss(0.30, 0.10)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mesh = _HeartMesh.instance;
    final rig = SceneLightRig(hero: hero);
    final beat = beatOf(time);
    final radial = 1 - 0.085 * beat;
    final vertical = 1 - 0.055 * beat;
    final float = math.sin(time * 0.45) * 0.06;
    // Repos : oscillation lente ±0,28 rad — jamais de rotation continue.
    final yaw = math.sin(time * 0.35) * 0.28;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final emissive = (hero ? 0.16 : 0.10) + beat * (hero ? 0.30 : 0.16);
    final alpha = hero ? 0.88 : 0.82;
    final worldScale = size.shortestSide * 0.30;
    final focal = 6.0;

    // Halo de pouls : dégradé radial animé (repli validé par le handoff).
    final haloIntensity =
        ((hero ? 0.20 : 0.10) + beat * (hero ? 0.30 : 0.16)) * 1.4;
    final haloColor = Color.lerp(
      AppColors.primary,
      AppColors.accent,
      beat * 0.3,
    )!;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide * 0.5 * (1 + beat * 0.06),
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          size.shortestSide * 0.5,
          [
            haloColor.withValues(alpha: haloIntensity.clamp(0.0, 1.0)),
            haloColor.withValues(alpha: 0),
          ],
          [0.0, 1.0],
        ),
    );

    // Particules orbitales déterministes — jamais dans le volume du cœur.
    final particleCount = hero ? 150 : 90;
    final particlePaint = Paint();
    for (var i = 0; i < particleCount; i++) {
      final seedA = hashNoise(i);
      final seedB = hashNoise(i + 1000);
      final seedC = hashNoise(i + 2000);
      final orbit = 1.35 + seedA * 0.9;
      final angle = seedB * 2 * math.pi + time * (0.05 + seedC * 0.08);
      final height = (seedC - 0.5) * 2.2;
      final x = orbit * math.cos(angle);
      final z = orbit * math.sin(angle) * 0.8;
      final centre = project(
        x * cosYaw + z * sinYaw,
        height + float,
        -x * sinYaw + z * cosYaw,
        focal: focal,
        size: size,
        worldScale: worldScale,
      );
      particlePaint.color = AppColors.primaryLight.withValues(
        alpha: (hero ? 0.5 : 0.26) * (0.4 + 0.6 * seedA),
      );
      canvas.drawCircle(centre, 0.9 + seedB * 1.3, particlePaint);
    }

    // Sommets : transformation + éclairage par frame.
    final count = _HeartMesh.rings * _HeartMesh.segments;
    final positions = Float32List(count * 2);
    final colors = Int32List(count);
    final viewZ = Float32List(count);
    const base = (0.18, 0.15, 0.38); // #2E2760

    for (var i = 0; i < count; i++) {
      final px = mesh.rest[i * 3] * radial;
      final py = mesh.rest[i * 3 + 1] * vertical + float;
      final pz = mesh.rest[i * 3 + 2] * radial;
      final x = px * cosYaw + pz * sinYaw;
      final z = -px * sinYaw + pz * cosYaw;

      final nxr = mesh.normals[i * 3];
      final ny = mesh.normals[i * 3 + 1];
      final nzr = mesh.normals[i * 3 + 2];
      final nx = nxr * cosYaw + nzr * sinYaw;
      final nz = -nxr * sinYaw + nzr * cosYaw;

      final offset = project(
        x,
        py,
        z,
        focal: focal,
        size: size,
        worldScale: worldScale,
      );
      positions[i * 2] = offset.dx;
      positions[i * 2 + 1] = offset.dy;
      viewZ[i] = z;

      // Fresnel : halo sur la silhouette (remplace le mesh de liseré).
      final fresnel = math.pow(1 - nz.abs().clamp(0.0, 1.0), 2.6).toDouble();
      final (r, g, b) = rig.shade(
        nx: nx,
        ny: ny,
        nz: nz,
        base: base,
        emissive: emissive + fresnel * (hero ? 0.16 : 0.10) * (0.6 + beat),
      );
      colors[i] = packColor(r, g, b, alpha);
    }

    // Élimination des faces arrière : le cœur ne montre jamais son
    // intérieur (équivalent depthWrite du handoff).
    final source = mesh.triangles;
    final visible = Uint16List(source.length);
    var cursor = 0;
    for (var t = 0; t < source.length; t += 3) {
      final a = source[t];
      final b = source[t + 1];
      final c = source[t + 2];
      final ax = positions[a * 2];
      final ay = positions[a * 2 + 1];
      final cross = (positions[b * 2] - ax) * (positions[c * 2 + 1] - ay) -
          (positions[c * 2] - ax) * (positions[b * 2 + 1] - ay);
      if (cross < 0 || viewZ[a] + viewZ[b] + viewZ[c] > 0.6) {
        visible[cursor++] = a;
        visible[cursor++] = b;
        visible[cursor++] = c;
      }
    }

    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        colors: colors,
        indices: Uint16List.sublistView(visible, 0, cursor),
      ),
      BlendMode.srcOver,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.hero != hero;
}
