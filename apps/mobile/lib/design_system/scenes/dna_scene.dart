import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'dna_animation.dart';
import 'dna_mesh.dart';
import 'scene3d.dart';

/// Rendu d'une image de la double hélice — portage fidèle de `dna-helix.js`
/// (mode « hero ») : mêmes matériaux, mêmes quatre lumières, même caméra et
/// même tone mapping ACES que la maquette WebGL.
///
/// Le maillage ([DnaMesh]) est immuable ; à chaque image on transforme et on
/// éclaire les sommets, on trie les parties en profondeur, puis on émet un
/// unique `drawVertices` dont les triangles vont du plus lointain au plus
/// proche — c'est ce qui rend correctement des tubes translucides sans
/// tampon de profondeur.
class DnaScenePainter extends CustomPainter {
  const DnaScenePainter({required this.time});

  /// Temps absolu (secondes) — pilote rotation, respiration et pulsations.
  final double time;

  /// Cadrage de la maquette : `camera.position.z = 13`, champ 30°,
  /// `root.rotation.z = 0.16`, `root.position.x = 0.9`, exposition 1,05.
  /// La vitesse de rotation vit dans [DnaAnimation], avec ce qui en dépend.
  static const double _cameraZ = 13;
  static const double _tiltZ = 0.16;
  static const double _offsetX = 0.9;

  /// Gain de luminosité appliqué aux matériaux et à l'exposition.
  ///
  /// La maquette est faite pour un écran de bureau ; sur téléphone, en
  /// extérieur, l'hélice devenait trop discrète. Le gain porte sur l'émissivité
  /// et l'opacité, pas sur les couleurs : la teinte reste celle du handoff.
  static const double _emissiveGain = 1.62;
  static const double _opacityGain = 1.55;

  static double _op(double value) =>
      (value * _opacityGain).clamp(0.0, 1.0).toDouble();

  /// Matériaux de la maquette, dans l'ordre de [DnaMaterialId].
  static final List<StandardMaterial> _materials = [
    _strand(0x9B30FF),
    _strand(0xC88BFF),
    StandardMaterial(
      base: LinearRgb.fromHex(0xFF7A45),
      emissive: LinearRgb.fromHex(0xFF7A45),
      emissiveIntensity: 0.5 * _emissiveGain,
      roughness: 0.4,
      metalness: 0,
      opacity: _op(0.6),
    ),
    StandardMaterial(
      base: const LinearRgb(1, 1, 1),
      emissive: LinearRgb.fromHex(0xC88BFF),
      emissiveIntensity: 0.35 * _emissiveGain,
      roughness: 0.5,
      metalness: 0,
      opacity: _op(0.4),
    ),
    _node(0xFF7A45, 0xFF7A45),
    _node(0xE7CCFF, 0x9B30FF),
  ];

  static StandardMaterial _strand(int hex) => StandardMaterial(
    base: LinearRgb.fromHex(hex),
    emissive: LinearRgb.fromHex(hex),
    emissiveIntensity: 0.6 * _emissiveGain,
    roughness: 0.3,
    metalness: 0.35,
    opacity: _op(0.8),
  );

  static StandardMaterial _node(int hex, int emissive) => StandardMaterial(
    base: LinearRgb.fromHex(hex),
    emissive: LinearRgb.fromHex(emissive),
    emissiveIntensity: 0.6 * _emissiveGain,
    roughness: 0.35,
    metalness: 0,
    opacity: _op(0.55),
  );

  static final SceneCamera _camera = SceneCamera(
    fovDegrees: 30,
    x: 0,
    y: 0,
    z: _cameraZ,
    targetX: 0,
    targetY: 0,
    targetZ: 0,
  );

  /// Les quatre lumières du mode hero, à l'unité près.
  static final SceneShader _shader = SceneShader(
    exposure: 1.12,
    cameraX: 0,
    cameraY: 0,
    cameraZ: _cameraZ,
    lights: [
      SceneLight.ambient(LinearRgb.fromHex(0xA84DFF).scaled(0.5)),
      SceneLight.point(
        LinearRgb.fromHex(0x9B30FF),
        30,
        x: 4,
        y: 5,
        z: 7,
        cutoff: 60,
      ),
      SceneLight.point(
        LinearRgb.fromHex(0xFF7A45),
        20,
        x: -5,
        y: -4,
        z: 5,
        cutoff: 60,
      ),
      SceneLight.directional(const LinearRgb(1, 1, 1), 0.5, x: -2, y: 3, z: -6),
    ],
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final mesh = DnaMesh.instance;

    // --- Animation de la maquette (voir DnaAnimation : tout boucle) ---
    final pose = DnaAnimation.poseAt(time);
    final rotation = EulerRotation(0, pose.spinY, _tiltZ);

    _shadeVertices(
      mesh,
      size,
      rotation,
      pose.breath,
      pose.breathY,
      pose.rungScale,
    );
    _draw(canvas, mesh);
  }

  /// Transformation, éclairage et projection de chaque sommet.
  void _shadeVertices(
    DnaMesh mesh,
    Size size,
    EulerRotation rotation,
    double breath,
    double breathY,
    Float64List rungScale,
  ) {
    final screen = mesh.screen;
    final facing = mesh.facing;
    final colors = mesh.colors;

    for (var v = 0; v < mesh.vertexCount; v++) {
      final rung = mesh.rungs[v];
      final radial = rung < 0 ? breath : breath * rungScale[rung];
      final i3 = v * 3;

      final lx = mesh.positions[i3] * radial;
      final ly = mesh.positions[i3 + 1] * breathY;
      final lz = mesh.positions[i3 + 2] * radial;

      // Normale d'un étirement diagonal : transposée inverse des échelles.
      var nx = mesh.normals[i3] / radial;
      var ny = mesh.normals[i3 + 1] / breathY;
      var nz = mesh.normals[i3 + 2] / radial;
      final nLength = math.sqrt(nx * nx + ny * ny + nz * nz);
      nx /= nLength;
      ny /= nLength;
      nz /= nLength;

      final wx = rotation.rotX(lx, ly, lz) + _offsetX;
      final wy = rotation.rotY(lx, ly, lz);
      final wz = rotation.rotZ(lx, ly, lz);
      final rnx = rotation.rotX(nx, ny, nz);
      final rny = rotation.rotY(nx, ny, nz);
      final rnz = rotation.rotZ(nx, ny, nz);

      final p = _camera.project(wx, wy, wz, size.width, size.height);
      screen[v * 2] = p.sx;
      screen[v * 2 + 1] = p.sy;
      // La caméra vise l'origine depuis +Z : la profondeur, c'est z.
      mesh.depth[v] = wz;
      // Élimination des faces arrière : signe de N · (caméra − P).
      facing[v] = -rnx * wx - rny * wy + rnz * (_cameraZ - wz);
      colors[v] = _shader.shade(
        rnx,
        rny,
        rnz,
        wx,
        wy,
        wz,
        _materials[mesh.materials[v]],
      );
    }
  }

  /// Émission des triangles visibles, du plus lointain au plus proche.
  ///
  /// Sans tampon de profondeur, l'ordre de dessin EST la profondeur. Trier par
  /// groupe (un brin, un barreau, une bille) ne suffit pas : deux groupes qui
  /// s'entrecroisent se départagent alors en bloc, et l'on voit une bille ou un
  /// barreau passer devant un brin qui devrait le masquer. Le tri se fait donc
  /// triangle par triangle, en un seul passage linéaire (tri par
  /// compartiments) — un tri comparatif sur quinze mille triangles coûterait
  /// bien plus cher à chaque image.
  void _draw(Canvas canvas, DnaMesh mesh) {
    final facing = mesh.facing;
    final depth = mesh.depth;
    final indices = mesh.indices;
    final starts = mesh.triangleStart;
    final keys = mesh.triangleDepth;
    final out = mesh.drawOrder;

    var visible = 0;
    var minDepth = double.infinity;
    var maxDepth = -double.infinity;
    for (var i = 0; i < indices.length; i += 3) {
      final a = indices[i];
      final b = indices[i + 1];
      final c = indices[i + 2];
      if (facing[a] + facing[b] + facing[c] <= 0) {
        continue;
      }
      final d = (depth[a] + depth[b] + depth[c]) / 3;
      starts[visible] = i;
      keys[visible] = d;
      if (d < minDepth) {
        minDepth = d;
      }
      if (d > maxDepth) {
        maxDepth = d;
      }
      visible++;
    }
    if (visible == 0) {
      return;
    }

    const buckets = DnaMesh.depthBuckets;
    final offsets = mesh.bucketOffsets..fillRange(0, buckets + 1, 0);
    final slots = mesh.triangleSlot;
    final span = maxDepth - minDepth;
    final scale = span > 1e-9 ? (buckets - 1) / span : 0.0;

    for (var t = 0; t < visible; t++) {
      final slot = ((keys[t] - minDepth) * scale).toInt();
      slots[t] = slot;
      offsets[slot]++;
    }
    var running = 0;
    for (var b = 0; b < buckets; b++) {
      final size = offsets[b];
      offsets[b] = running;
      running += size;
    }
    for (var t = 0; t < visible; t++) {
      final position = offsets[slots[t]]++ * 3;
      final i = starts[t];
      out[position] = indices[i];
      out[position + 1] = indices[i + 1];
      out[position + 2] = indices[i + 2];
    }
    final n = visible * 3;

    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        mesh.screen,
        colors: mesh.colors,
        indices: Uint16List.sublistView(out, 0, n),
      ),
      BlendMode.srcOver,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(DnaScenePainter oldDelegate) => oldDelegate.time != time;
}
