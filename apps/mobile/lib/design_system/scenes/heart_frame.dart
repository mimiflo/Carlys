import 'dart:math' as math;
import 'dart:typed_data';

import 'scene3d.dart';

/// Calcul PUR d'une image du cœur — aucun canvas, aucun widget.
///
/// C'est la moitié chère de la scène (déformation, projection, tri,
/// éclairage de ~12 000 sommets) : la sortir dans une fonction pure permet
/// de l'exécuter dans un ISOLATE (voir `heart_engine.dart`), hors du fil
/// d'interface — le défilement ne partage plus son budget avec le cœur.
/// Le peintre, lui, ne fait plus que dessiner des tampons prêts.
///
/// La planche de contrôle et les tests appellent cette fonction en
/// synchrone : mêmes mathématiques, mêmes pixels, quel que soit le fil.
class HeartFrameRequest {
  const HeartFrameRequest({
    required this.seconds,
    required this.hero,
    required this.still,
    required this.width,
    required this.height,
  });

  final double seconds;
  final bool hero;

  /// Pose figée (réduction d'animations) : diastole franche.
  final bool still;
  final double width;
  final double height;
}

/// Tampons prêts à dessiner pour UNE image : maillage principal, voile
/// interne, et les scalaires (battement, ballant) dont halo et particules
/// ont besoin pour rester COHÉRENTS avec le maillage de cette image.
class HeartFrame {
  const HeartFrame({
    required this.seconds,
    required this.hero,
    required this.width,
    required this.height,
    required this.beat,
    required this.bob,
    required this.screen,
    required this.colors,
    required this.indices,
    required this.wide,
    required this.coreColors,
    required this.coreIndices,
    required this.computeMicros,
  });

  final double seconds;
  final bool hero;
  final double width;
  final double height;
  final double beat;
  final double bob;

  /// Sommets écran + couleurs éclairées + faces émises (avant→arrière déjà
  /// triées) du maillage principal.
  final Float32List screen;
  final Int32List colors;
  final Uint16List indices;

  /// Voile interne : silhouette dilatée + couleurs constantes + faces.
  final Float32List wide;
  final Int32List coreColors;
  final Uint16List coreIndices;

  /// Coût du calcul, rapporté à la cadence adaptative.
  final int computeMicros;
}

/// Courbe cardiaque : systole marquée puis rebond diastolique.
double heartBeatAt(double phase) {
  double g(double c, double w) {
    final d = (phase - c) / w;
    return math.exp(-d * d);
  }

  return g(0.08, 0.055) + g(0.30, 0.075) * 0.42;
}

/// La caméra de la maquette — le peintre la reconstruit pour halo et
/// particules, le calcul d'image pour la projection : même objet.
SceneCamera heartCamera() => SceneCamera(
      fovDegrees: 32,
      x: 0.1,
      y: 0.15,
      z: 7.4,
      targetX: 0,
      targetY: -0.05,
      targetZ: 0,
    );

final LinearRgb heartViolet = LinearRgb.fromHex(0x9B30FF);
final LinearRgb heartAccent = LinearRgb.fromHex(0xFF7A45);
final LinearRgb _baseColor = LinearRgb.fromHex(0x361A66);

HeartFrame computeHeartFrame(HeartFrameRequest request) {
  final stopwatch = Stopwatch()..start();
  final seconds = request.seconds;
  final hero = request.hero;

  final period = 60 / 57;
  final phase = (seconds % period) / period;
  final beat = request.still ? 0.0 : heartBeatAt(phase);

  final mesh = _HeartMesh.forSize(math.min(request.width, request.height));
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

  final camera = heartCamera();

  final material = StandardMaterial(
    base: _baseColor,
    emissive: heartViolet,
    emissiveIntensity: (hero ? 0.82 : 0.62) + beat * (hero ? 1.5 : 0.9),
    roughness: 0.42,
    metalness: 0.3,
    opacity: hero ? 0.88 : 0.82,
  );

  final shader = SceneShader(
    exposure: hero ? 1.34 : 1.12,
    cameraX: camera.x,
    cameraY: camera.y,
    cameraZ: camera.z,
    lights: [
      SceneLight.ambient(LinearRgb.fromHex(0x5A2A8A).scaled(0.55)),
      SceneLight.point(
        LinearRgb.fromHex(0xD3A8FF),
        hero ? 40 : 22,
        x: 3.2,
        y: 3.6,
        z: 5,
        cutoff: 40,
      ),
      SceneLight.point(
        LinearRgb.fromHex(0xFF7A45),
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

  // --- Sommets : déformation, transformation, projection ---
  // L'ÉCLAIRAGE, lui, attend l'émission des faces : la moitié arrière du
  // maillage n'est jamais dessinée, l'éclairer était le poste le plus cher.
  final screen = mesh.screen;
  final colors = mesh.colors;
  final viewDepth = mesh.depth;
  final world = mesh.world;
  final worldNormals = mesh.worldNormals;

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

    world[i3] = wx;
    world[i3 + 1] = wy;
    world[i3 + 2] = wz;
    worldNormals[i3] = rotation.rotX(nx, ny, nz);
    worldNormals[i3 + 1] = rotation.rotY(nx, ny, nz);
    worldNormals[i3 + 2] = rotation.rotZ(nx, ny, nz);

    // Projection SANS allocation : à douze mille sommets par image, la
    // version à enregistrement nourrissait le ramasse-miettes pour rien.
    camera.projectInto(
      screen,
      viewDepth,
      v,
      wx,
      wy,
      wz,
      request.width,
      request.height,
    );
  }

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

  // --- Éclairage : seulement les sommets d'une face émise ---
  final used = mesh.used;
  used.fillRange(0, used.length, 0);
  for (var i = 0; i < n; i++) {
    used[indices[i]] = 1;
  }
  for (var v = 0; v < vertexCount; v++) {
    if (used[v] == 0) {
      continue;
    }
    final i3 = v * 3;
    colors[v] = shader.shade(
      worldNormals[i3],
      worldNormals[i3 + 1],
      worldNormals[i3 + 2],
      world[i3],
      world[i3 + 1],
      world[i3 + 2],
      material,
    );
  }

  // --- Voile interne : les faces arrière en aplat additif pâle. C'est ce
  // qui donne au volume sa densité sans dessiner la moindre structure. ---
  // Le voile est un second maillage 6 % plus grand : on dilate la silhouette
  // projetée autour de son centre plutôt que de refaire une projection.
  const spread = 1.72 / 1.62;
  const stride = 3;
  var cx = 0.0;
  var cy = 0.0;
  for (var i = 0; i < vertexCount; i++) {
    cx += screen[i * 2];
    cy += screen[i * 2 + 1];
  }
  cx /= vertexCount;
  cy /= vertexCount;
  final wide = mesh.wide;
  for (var i = 0; i < vertexCount; i++) {
    wide[i * 2] = cx + (screen[i * 2] - cx) * spread;
    wide[i * 2 + 1] = cy + (screen[i * 2 + 1] - cy) * spread;
  }

  final coreColors = mesh.coreColors;
  final alpha = ((hero ? 0.16 : 0.10) * 255).round();
  const pale = 0xC88BFF;
  final packed = (alpha << 24) | pale;
  if (coreColors.isNotEmpty && coreColors[0] != packed) {
    coreColors.fillRange(0, coreColors.length, packed);
  }

  final coreIndices = mesh.coreFaces;
  var m = 0;
  for (var k = 0; k + stride <= mesh.rings; k += stride) {
    for (var i = 0; i + stride <= mesh.segments; i += stride) {
      final a = k * row + i;
      final b = a + stride;
      final c = a + row * stride;
      final d = c + stride;
      // Ordre inversé : on ne garde que les faces arrière.
      m = _emit(coreIndices, m, wide, c, a, b);
      m = _emit(coreIndices, m, wide, c, b, d);
    }
  }

  stopwatch.stop();

  // Copies TRONQUÉES aux faces émises : l'image est un instantané autonome,
  // les tampons de travail du maillage resservent à l'image suivante.
  return HeartFrame(
    seconds: seconds,
    hero: hero,
    width: request.width,
    height: request.height,
    beat: beat,
    bob: bob,
    screen: Float32List.fromList(screen),
    colors: Int32List.fromList(colors),
    indices: Uint16List.fromList(Uint16List.sublistView(indices, 0, n)),
    wide: Float32List.fromList(wide),
    coreColors: Int32List.fromList(coreColors),
    coreIndices: Uint16List.fromList(Uint16List.sublistView(coreIndices, 0, m)),
    computeMicros: stopwatch.elapsedMicroseconds,
  );
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

/// Maillage du cœur, construit une seule fois PAR ISOLATE.
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

  /// Maillages par niveau de détail, construits à la première demande.
  ///
  /// La maquette rend 120 × 160 sur un écran de bureau ; à 300 points de côté
  /// sur un téléphone, un segment ferait moins de deux pixels — autant de
  /// sommets éclairés pour rien. La densité suit donc la taille réellement
  /// rendue, et le reflet spéculaire reste net là où il se voit.
  static final Map<int, _HeartMesh> _cache = {};

  static _HeartMesh forSize(double side) {
    final rings = side < 240
        ? 56
        : side < 420
            ? 96
            : 120;
    return _cache.putIfAbsent(
      rings,
      () => _HeartMesh._(rings, (rings * 4 ~/ 3)),
    );
  }

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

  /// Position et normale monde par sommet — retenues pour n'ÉCLAIRER que
  /// les sommets des faces réellement dessinées (voir `used`).
  late final Float32List world = Float32List(positions.length);
  late final Float32List worldNormals = Float32List(positions.length);

  /// 1 si le sommet appartient à une face émise : la moitié arrière du
  /// maillage est éliminée AVANT l'éclairage, le poste le plus cher.
  late final Uint8List used = Uint8List(positions.length ~/ 3);

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
