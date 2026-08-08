import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'scene3d.dart';

/// Cœur battant de la refonte — portage fidèle de `pulse-heart.js`.
///
/// Même géométrie (profil cardiaque révolutionné, 1,05 × 1,02 × 0,86), même
/// matériau (violet auto-éclairé, rugosité 0,42, métallicité 0,3), mêmes
/// lumières et même tone mapping ACES que la maquette : le rendu doit être
/// indiscernable de la référence WebGL.
///
/// Le battement est calé sur 57 bpm (fréquence de repos d'un athlète).
class HeartScene extends StatefulWidget {
  const HeartScene({this.hero = false, super.key});

  /// Mode « hero » : plus opaque et plus lumineux que le mode d'ambiance.
  final bool hero;

  @override
  State<HeartScene> createState() => _HeartSceneState();
}

class _HeartSceneState extends State<HeartScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La boucle ne doit JAMAIS tourner sous réduction d'animations : sinon la
    // scène empêche toute stabilisation (accessibilité, et tests de widgets).
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
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
    // Réduction d'animations : on fige le cœur sur une pose de diastole.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      return CustomPaint(
        painter: _HeartPainter(seconds: 0, hero: widget.hero, still: true),
        size: Size.infinite,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _HeartPainter(
          seconds: _controller.value * 30,
          hero: widget.hero,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Maillage du cœur, construit une seule fois pour toute l'application.
class _HeartMesh {
  _HeartMesh._(this.rings, this.segments) {
    final row = segments + 1;
    final count = (rings + 1) * row;
    positions = Float32List(count * 3);
    normals = Float32List(count * 3);

    var p = 0;
    for (var k = 0; k <= rings; k++) {
      final th = (k / rings) * math.pi;
      final s = math.sin(th);
      final z = math.cos(th) * _depth;
      for (var i = 0; i <= segments; i++) {
        final t = (i / segments) * math.pi * 2;
        final sinT = math.sin(t);
        final hx = sinT * sinT * sinT;
        final hy = (13 * math.cos(t) -
                5 * math.cos(2 * t) -
                2 * math.cos(3 * t) -
                math.cos(4 * t)) /
            16;
        positions[p++] = hx * s * 1.05;
        positions[p++] = (hy * s - 0.12) * 1.02;
        positions[p++] = z * s * 0.92 + z * 0.08;
      }
    }

    _computeNormals(row);
  }

  static const double _depth = 0.86;
  static final _HeartMesh instance = _HeartMesh._(120, 160);

  final int rings;
  final int segments;
  late final Float32List positions;
  late final Float32List normals;

  /// Tampons de travail, alloués une fois pour toutes.
  late final Float32List screen = Float32List(positions.length ~/ 3 * 2);
  late final Float32List wide = Float32List(positions.length ~/ 3 * 2);
  late final Int32List colors = Int32List(positions.length ~/ 3);
  late final Int32List coreColors = Int32List(positions.length ~/ 3);
  late final Float32List depth = Float32List(positions.length ~/ 3);
  late final Uint16List faces = Uint16List(rings * segments * 6);
  late final Uint16List coreFaces = Uint16List(rings * segments * 6);

  /// Normales moyennées par sommet, comme `computeVertexNormals`.
  void _computeNormals(int row) {
    final acc = Float32List(normals.length);
    void addFace(int a, int b, int c) {
      final ax = positions[a * 3], ay = positions[a * 3 + 1];
      final az = positions[a * 3 + 2];
      final e1x = positions[b * 3] - ax;
      final e1y = positions[b * 3 + 1] - ay;
      final e1z = positions[b * 3 + 2] - az;
      final e2x = positions[c * 3] - ax;
      final e2y = positions[c * 3 + 1] - ay;
      final e2z = positions[c * 3 + 2] - az;
      final nx = e1y * e2z - e1z * e2y;
      final ny = e1z * e2x - e1x * e2z;
      final nz = e1x * e2y - e1y * e2x;
      for (final v in [a, b, c]) {
        acc[v * 3] += nx;
        acc[v * 3 + 1] += ny;
        acc[v * 3 + 2] += nz;
      }
    }

    for (var k = 0; k < rings; k++) {
      for (var i = 0; i < segments; i++) {
        final a = k * row + i;
        final b = a + 1;
        final c = a + row;
        final d = c + 1;
        addFace(a, c, b);
        addFace(b, c, d);
      }
    }

    for (var v = 0; v < acc.length; v += 3) {
      final x = acc[v], y = acc[v + 1], z = acc[v + 2];
      final len = math.sqrt(x * x + y * y + z * z);
      if (len > 1e-9) {
        normals[v] = x / len;
        normals[v + 1] = y / len;
        normals[v + 2] = z / len;
      } else {
        normals[v + 1] = 1;
      }
    }
  }
}

/// Rendu d'une image du cœur.
class _HeartPainter extends CustomPainter {
  _HeartPainter({
    required this.seconds,
    required this.hero,
    this.still = false,
  });

  final double seconds;
  final bool hero;

  /// Pose figée (réduction d'animations) : diastole franche, sans contraction.
  final bool still;

  static final LinearRgb _violet = LinearRgb.fromHex(0x5B5BF6);
  static final LinearRgb _lime = LinearRgb.fromHex(0xC6F432);
  static final LinearRgb _baseColor = LinearRgb.fromHex(0x2E2760);

  /// Courbe cardiaque : systole marquée puis rebond diastolique.
  static double _cardiac(double p) {
    double g(double c, double w) {
      final d = (p - c) / w;
      return math.exp(-d * d);
    }

    return g(0.08, 0.055) + g(0.30, 0.075) * 0.42;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final period = 60 / 57;
    final phase = (seconds % period) / period;
    final beat = still ? 0.0 : _cardiac(phase);

    final mesh = _HeartMesh.instance;
    final row = mesh.segments + 1;
    final vertexCount = (mesh.rings + 1) * row;

    // --- Transformations de la maquette ---
    final rotation = EulerRotation(
      0.16,
      -0.42 + math.sin(seconds * 0.22) * 0.28,
      0.18,
    );
    final bob = math.sin(seconds * 0.45) * 0.06;
    final scale = 1.62 * (1 + beat * 0.035);

    final camera = SceneCamera(
      fovDegrees: 32,
      x: 0.1,
      y: 0.15,
      z: 7.4,
      targetX: 0,
      targetY: -0.05,
      targetZ: 0,
    );

    final material = StandardMaterial(
      base: _baseColor,
      emissive: _violet,
      emissiveIntensity: (hero ? 0.72 : 0.5) + beat * (hero ? 1.5 : 0.9),
      roughness: 0.42,
      metalness: 0.3,
      opacity: hero ? 0.88 : 0.82,
    );

    final shader = SceneShader(
      exposure: hero ? 1.3 : 1.05,
      cameraX: camera.x,
      cameraY: camera.y,
      cameraZ: camera.z,
      lights: [
        SceneLight.ambient(LinearRgb.fromHex(0x4A4A9A).scaled(0.55)),
        SceneLight.point(
          LinearRgb.fromHex(0x9A9AFF),
          hero ? 40 : 22,
          x: 3.2,
          y: 3.6,
          z: 5,
          cutoff: 40,
        ),
        SceneLight.point(
          LinearRgb.fromHex(0xC6F432),
          hero ? 18 : 9,
          x: -3.6,
          y: -2.4,
          z: 3,
          cutoff: 40,
        ),
        SceneLight.directional(
          const LinearRgb(1, 1, 1),
          hero ? 0.42 : 0.22,
          x: -2.5,
          y: 1.5,
          z: -5,
        ),
      ],
    );

    // --- Sommets : déformation, transformation, éclairage ---
    final screen = mesh.screen;
    final colors = mesh.colors;
    final viewDepth = mesh.depth;

    final squeezeY = 1 - beat * 0.055;
    for (var v = 0; v < vertexCount; v++) {
      final i3 = v * 3;
      final bx = mesh.positions[i3];
      final by = mesh.positions[i3 + 1];
      final bz = mesh.positions[i3 + 2];

      // Contraction du muscle (identique à la maquette).
      final twist = math.sin(by * 2.4 + seconds * 0.8) * 0.012;
      final k = 1 - beat * 0.085 + twist;

      final dx = bx * k * scale;
      final dy = by * squeezeY * scale;
      final dz = bz * k * scale;

      // Normale : transposée inverse d'un étirement diagonal.
      var nx = mesh.normals[i3] / k;
      var ny = mesh.normals[i3 + 1] / squeezeY;
      var nz = mesh.normals[i3 + 2] / k;
      final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
      nx /= nLen;
      ny /= nLen;
      nz /= nLen;

      final wx = rotation.rotX(dx, dy, dz);
      final wy = rotation.rotY(dx, dy, dz) + bob;
      final wz = rotation.rotZ(dx, dy, dz);

      final rnx = rotation.rotX(nx, ny, nz);
      final rny = rotation.rotY(nx, ny, nz);
      final rnz = rotation.rotZ(nx, ny, nz);

      final p = camera.project(wx, wy, wz, size.width, size.height);
      screen[v * 2] = p.sx;
      screen[v * 2 + 1] = p.sy;
      viewDepth[v] = p.viewZ;
      colors[v] = shader.shade(rnx, rny, rnz, wx, wy, wz, material);
    }

    // --- Halo interne, sous le maillage ---
    _paintHalo(canvas, size, camera, bob, beat);

    // --- Voile interne : silhouette additive qui donne sa densité au volume
    // (le maillage `core` en BackSide de la maquette). ---
    _paintCore(canvas, screen, mesh, row);

    // --- Faces avant, des plus lointaines aux plus proches ---
    final ringOrder = List<int>.generate(mesh.rings, (i) => i);
    ringOrder.sort((a, b) {
      final za = viewDepth[a * row] + viewDepth[(a + 1) * row];
      final zb = viewDepth[b * row] + viewDepth[(b + 1) * row];
      return za.compareTo(zb);
    });

    final indices = mesh.faces;
    var n = 0;
    for (final k in ringOrder) {
      for (var i = 0; i < mesh.segments; i++) {
        final a = k * row + i;
        final b = a + 1;
        final c = a + row;
        final d = c + 1;
        n = _emit(indices, n, screen, a, c, b);
        n = _emit(indices, n, screen, b, c, d);
      }
    }

    if (n > 0) {
      canvas.drawVertices(
        ui.Vertices.raw(
          ui.VertexMode.triangles,
          screen,
          colors: colors,
          indices: Uint16List.sublistView(indices, 0, n),
        ),
        BlendMode.srcOver,
        Paint(),
      );
    }

    _paintParticles(canvas, size, camera, rotation, bob, beat);
  }

  /// N'émet un triangle que s'il fait face à la caméra (aire 2D signée).
  int _emit(Uint16List out, int n, Float32List screen, int a, int b, int c) {
    final ax = screen[a * 2], ay = screen[a * 2 + 1];
    final bx = screen[b * 2], by = screen[b * 2 + 1];
    final cx = screen[c * 2], cy = screen[c * 2 + 1];
    final area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    if (area <= 0) {
      return n;
    }
    out[n] = a;
    out[n + 1] = b;
    out[n + 2] = c;
    return n + 3;
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
    final glow = _violet.lerpTo(_lime, beat * 0.30);
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
      colors.add(color.withValues(alpha: (fresnel * intensity).clamp(0.0, 1.0)));
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

  /// Voile interne : les faces arrière du cœur en aplat additif pâle. C'est ce
  /// qui donne au volume sa densité sans dessiner la moindre structure.
  void _paintCore(
    Canvas canvas,
    Float32List screen,
    _HeartMesh mesh,
    int row,
  ) {
    final count = screen.length ~/ 2;
    const stride = 3;

    // Le voile est un second maillage 6 % plus grand : on dilate la silhouette
    // projetée autour de son centre plutôt que de refaire une projection.
    const spread = 1.72 / 1.62;
    var cx = 0.0;
    var cy = 0.0;
    for (var i = 0; i < count; i++) {
      cx += screen[i * 2];
      cy += screen[i * 2 + 1];
    }
    cx /= count;
    cy /= count;
    final wide = mesh.wide;
    for (var i = 0; i < count; i++) {
      wide[i * 2] = cx + (screen[i * 2] - cx) * spread;
      wide[i * 2 + 1] = cy + (screen[i * 2 + 1] - cy) * spread;
    }

    final colors = mesh.coreColors;
    final alpha = ((hero ? 0.16 : 0.10) * 255).round();
    const pale = 0x8A8AFA;
    final packed = (alpha << 24) | pale;
    if (colors.isNotEmpty && colors[0] != packed) {
      colors.fillRange(0, colors.length, packed);
    } else if (colors.isNotEmpty && colors[0] == 0) {
      colors.fillRange(0, colors.length, packed);
    }

    final indices = mesh.coreFaces;
    var n = 0;
    for (var k = 0; k + stride <= mesh.rings; k += stride) {
      for (var i = 0; i + stride <= mesh.segments; i += stride) {
        final a = k * row + i;
        final b = a + stride;
        final c = a + row * stride;
        final d = c + stride;
        // Ordre inversé : on ne garde que les faces arrière.
        n = _emit(indices, n, wide, c, a, b);
        n = _emit(indices, n, wide, c, b, d);
      }
    }
    if (n == 0) {
      return;
    }

    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        wide,
        colors: colors,
        indices: Uint16List.sublistView(indices, 0, n),
      ),
      BlendMode.plus,
      Paint(),
    );
  }

  /// Flux sanguin : points déterministes en orbite (aucun aléatoire, le rendu
  /// doit être reproductible d'une image à l'autre et d'un test à l'autre).
  void _paintParticles(
    Canvas canvas,
    Size size,
    SceneCamera camera,
    EulerRotation rotation,
    double bob,
    double beat,
  ) {
    const count = 140;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..color = const Color(0xFFD6D6FF).withValues(alpha: hero ? 0.5 : 0.26);

    for (var i = 0; i < count; i++) {
      final h1 = _hash(i * 1.0);
      final h2 = _hash(i * 1.0 + 97);
      final h3 = _hash(i * 1.0 + 211);
      final h4 = _hash(i * 1.0 + 331);

      final r = (2.5 + h1 * 1.7) * (1 + beat * 0.08);
      final angle = h2 * math.pi * 2 + seconds * (0.15 + h4 * 0.4) * 0.4;
      final y = (h3 - 0.5) * 3.4 + math.sin(seconds * 0.5 + h2 * math.pi * 2) * 0.16;

      final lx = math.cos(angle) * r;
      final lz = math.sin(angle) * r;

      final wx = rotation.rotX(lx, y, lz);
      final wy = rotation.rotY(lx, y, lz) + bob;
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

  /// Bruit déterministe 0..1.
  static double _hash(double n) {
    final s = math.sin(n * 127.1) * 43758.5453;
    return s - s.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _HeartPainter old) =>
      old.seconds != seconds || old.hero != hero || old.still != still;
}
