import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
  /// `root.rotation.z = 0.16`, `root.position.x = 0.9`, exposition 1,05,
  /// `speed = 0.22`.
  static const double _cameraZ = 13;
  static const double _tiltZ = 0.16;
  static const double _offsetX = 0.9;
  static const double _spin = 0.22;

  /// Gain de luminosité appliqué aux matériaux et à l'exposition.
  ///
  /// La maquette est faite pour un écran de bureau ; sur téléphone, en
  /// extérieur, l'hélice devenait trop discrète. Le gain porte sur l'émissivité
  /// et l'opacité, pas sur les couleurs : la teinte reste celle du handoff.
  static const double _emissiveGain = 1.7;
  static const double _opacityGain = 1.22;

  static double _op(double value) =>
      (value * _opacityGain).clamp(0.0, 1.0).toDouble();

  /// Matériaux de la maquette, dans l'ordre de [DnaMaterialId].
  static final List<StandardMaterial> _materials = [
    _strand(0x5B5BF6),
    _strand(0x8A8AFA),
    StandardMaterial(
      base: LinearRgb.fromHex(0xC6F432),
      emissive: LinearRgb.fromHex(0xC6F432),
      emissiveIntensity: 0.5 * _emissiveGain,
      roughness: 0.4,
      metalness: 0,
      opacity: _op(0.6),
    ),
    StandardMaterial(
      base: const LinearRgb(1, 1, 1),
      emissive: LinearRgb.fromHex(0x8A8AFA),
      emissiveIntensity: 0.35 * _emissiveGain,
      roughness: 0.5,
      metalness: 0,
      opacity: _op(0.4),
    ),
    _node(0xC6F432, 0xC6F432),
    _node(0xC9C9FF, 0x5B5BF6),
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
    exposure: 1.22,
    cameraX: 0,
    cameraY: 0,
    cameraZ: _cameraZ,
    lights: [
      SceneLight.ambient(LinearRgb.fromHex(0x6A6AFF).scaled(0.5)),
      SceneLight.point(
        LinearRgb.fromHex(0x5B5BF6),
        30,
        x: 4,
        y: 5,
        z: 7,
        cutoff: 60,
      ),
      SceneLight.point(
        LinearRgb.fromHex(0xC6F432),
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

    // --- Animation de la maquette ---
    final rotation = EulerRotation(0, time * _spin, _tiltZ);
    final breath = 1 + math.sin(time * 0.65) * 0.03;
    final breathY = 1 + math.sin(time * 0.65) * 0.008;
    final rungScale = Float64List(DnaMesh.rungCount);
    for (var i = 0; i < DnaMesh.rungCount; i++) {
      final pulse = 0.5 + 0.5 * math.sin(time * 1.4 - DnaMesh.rungPhases[i]);
      rungScale[i] = 0.985 + pulse * 0.03;
    }

    _shadeVertices(mesh, size, rotation, breath, breathY, rungScale);
    _sortParts(mesh, rotation, breath, rungScale);
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

  /// Tri des parties du plus lointain au plus proche : la caméra vise
  /// l'origine depuis +Z, la profondeur de vue est donc simplement `z`.
  void _sortParts(
    DnaMesh mesh,
    EulerRotation rotation,
    double breath,
    Float64List rungScale,
  ) {
    final depth = mesh.partDepth;
    for (var i = 0; i < mesh.parts.length; i++) {
      final part = mesh.parts[i];
      final radial = part.group < 0 ? breath : breath * rungScale[part.group];
      depth[i] = rotation.rotZ(part.cx * radial, part.cy, part.cz * radial);
    }
    mesh.partOrder.sort((a, b) => depth[a].compareTo(depth[b]));
  }

  /// Émission des triangles visibles, dans l'ordre de profondeur.
  void _draw(Canvas canvas, DnaMesh mesh) {
    final facing = mesh.facing;
    final indices = mesh.indices;
    final out = mesh.drawOrder;
    var n = 0;

    for (final partIndex in mesh.partOrder) {
      final part = mesh.parts[partIndex];
      final end = part.first + part.count;
      for (var i = part.first; i < end; i += 3) {
        final a = indices[i];
        final b = indices[i + 1];
        final c = indices[i + 2];
        if (facing[a] + facing[b] + facing[c] <= 0) {
          continue;
        }
        out[n] = a;
        out[n + 1] = b;
        out[n + 2] = c;
        n += 3;
      }
    }
    if (n == 0) {
      return;
    }

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
