/// Géométrie de la double hélice d'ADN — portage fidèle de `dna-helix.js`
/// (mode « hero »).
///
/// Le maillage est construit UNE seule fois pour toute l'application : deux
/// brins en TUBE le long d'une courbe hélicoïdale, puis 26 barreaux faits de
/// deux demi-cylindres et de deux billes. Chaque partie ([MeshPart]) porte son
/// centre local, ce qui permet au peintre de trier en profondeur à chaque
/// image sans jamais retoucher la géométrie.
///
/// Les constantes ci-dessous ne sont pas des valeurs visuelles arbitraires :
/// ce sont les cotes de la maquette, la définition même de la scène.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'mesh_builder.dart';

/// Indices des matériaux de la scène ; le peintre tient la table associée.
abstract final class DnaMaterialId {
  /// Brin 1 — violet `0x9B30FF`.
  static const int strandA = 0;

  /// Brin 2 — violet clair `0xC88BFF`, déphasé de π.
  static const int strandB = 1;

  /// Barreau orange `0xFF7A45`, un sur trois.
  static const int rungAccent = 2;

  /// Barreau blanc à émission violette.
  static const int rungPlain = 3;

  /// Bille orange, au rythme des barreaux accentués.
  static const int nodeAccent = 4;

  /// Bille `0xE7CCFF` à émission violette.
  static const int nodePlain = 5;
}

/// Maillage complet de l'hélice, en espace local du groupe `root`.
class DnaMesh {
  DnaMesh._() {
    final builder = MeshBuilder();
    _addStrand(builder, 0, DnaMaterialId.strandA);
    _addStrand(builder, math.pi, DnaMaterialId.strandB);
    for (var index = 0; index < rungCount; index++) {
      _addRung(builder, index);
    }

    positions = Float32List.fromList(builder.positions);
    normals = Float32List.fromList(builder.normals);
    materials = Uint8List.fromList(builder.materials);
    rungs = Int8List.fromList(builder.groups);
    indices = Uint16List.fromList(builder.indices);
    parts = List<MeshPart>.unmodifiable(builder.parts);
    vertexCount = positions.length ~/ 3;
  }

  /// Singleton : la construction coûte quelques millisecondes, jamais répétées.
  static final DnaMesh instance = DnaMesh._();

  // --- Cotes de la maquette (mode hero) ---
  static const double radius = 1.32;
  static const double height = 9.4;
  static const double turns = 2.4;

  /// Brins volontairement plus épais que la maquette (0,082) : sur téléphone,
  /// l'hélice doit se lire d'un coup d'œil. La luminosité, elle, est au
  /// plafond — au-delà le tone mapping délave le violet vers le blanc.
  static const double tubeRadius = 0.104;
  static const int tubeSteps = 180;
  static const int tubeSides = 20;
  static const int rungCount = 26;
  static const double rungRadius = 0.032;
  static const int rungSides = 10;
  static const double nodeRadius = 0.05;

  /// Décalage du demi-barreau depuis le centre (`lerp(mid, end, 0.52)`) et sa
  /// demi-longueur (`len * 0.44 / 2`) : c'est ce couple qui ménage le jeu
  /// central, la liaison hydrogène de la maquette.
  static const double rungOffset = 0.52;
  static const double rungHalfLength = 0.44;

  late final Float32List positions;
  late final Float32List normals;
  late final Uint8List materials;

  /// Barreau propriétaire de chaque sommet, −1 pour un brin.
  late final Int8List rungs;
  late final Uint16List indices;
  late final List<MeshPart> parts;
  late final int vertexCount;

  /// Phase de respiration de chaque barreau (`t * 4π` dans la maquette).
  static final Float64List rungPhases = Float64List.fromList([
    for (var i = 0; i < rungCount; i++) (i + 0.5) / rungCount * 4 * math.pi,
  ]);

  /// Tampons de travail du peintre, alloués une fois pour toutes.
  late final Float32List screen = Float32List(vertexCount * 2);

  /// Profondeur de vue par sommet — base du tri par triangle.
  late final Float32List depth = Float32List(vertexCount);

  /// Tri par compartiments : un passage linéaire au lieu d'un tri comparatif.
  late final int triangleCount = indices.length ~/ 3;
  late final Int32List triangleStart = Int32List(triangleCount);
  late final Float32List triangleDepth = Float32List(triangleCount);
  late final Int32List triangleSlot = Int32List(triangleCount);
  late final Int32List bucketOffsets = Int32List(depthBuckets + 1);

  /// Résolution du tri : au-delà, deux triangles sont visuellement confondus.
  static const int depthBuckets = 1024;
  late final Float32List facing = Float32List(vertexCount);
  late final Int32List colors = Int32List(vertexCount);
  late final Uint16List drawOrder = Uint16List(indices.length);
  late final Float64List partDepth = Float64List(parts.length);
  late final List<int> partOrder =
      List<int>.generate(parts.length, (index) => index);

  /// Brin en tube : repère parallèle transporté le long de l'hélice, donc
  /// aucune vrille des anneaux d'un bout à l'autre.
  static void _addStrand(MeshBuilder b, double phase, int material) {
    b.material = material;
    b.group = -1;
    const twoPi = 2 * math.pi;
    const k = turns * twoPi;

    // Normale initiale : la principale de l'hélice, dirigée vers l'axe.
    var nx = -math.cos(phase);
    var ny = 0.0;
    var nz = -math.sin(phase);

    var previousRing = 0;
    var previousX = 0.0;
    var previousY = 0.0;
    var previousZ = 0.0;

    for (var step = 0; step <= tubeSteps; step++) {
      final t = step / tubeSteps;
      final theta = t * k + phase;
      final cx = math.cos(theta) * radius;
      final cy = (t - 0.5) * height;
      final cz = math.sin(theta) * radius;

      // Tangente analytique de l'hélice.
      var tx = -math.sin(theta) * radius * k;
      var ty = height;
      var tz = math.cos(theta) * radius * k;
      final tLength = math.sqrt(tx * tx + ty * ty + tz * tz);
      tx /= tLength;
      ty /= tLength;
      tz /= tLength;

      // Transport parallèle : on reprojette la normale précédente.
      final drift = nx * tx + ny * ty + nz * tz;
      nx -= tx * drift;
      ny -= ty * drift;
      nz -= tz * drift;
      final nLength = math.sqrt(nx * nx + ny * ny + nz * nz);
      nx /= nLength;
      ny /= nLength;
      nz /= nLength;

      final bx = ty * nz - tz * ny;
      final by = tz * nx - tx * nz;
      final bz = tx * ny - ty * nx;

      final ring = b.vertexCount;
      for (var side = 0; side <= tubeSides; side++) {
        final angle = side / tubeSides * twoPi;
        final c = math.cos(angle);
        final s = math.sin(angle);
        final ox = nx * c + bx * s;
        final oy = ny * c + by * s;
        final oz = nz * c + bz * s;
        b.addVertex(
          cx + ox * tubeRadius,
          cy + oy * tubeRadius,
          cz + oz * tubeRadius,
          ox,
          oy,
          oz,
        );
      }

      if (step > 0) {
        b.beginPart();
        for (var side = 0; side < tubeSides; side++) {
          b.addQuad(
            previousRing + side,
            previousRing + side + 1,
            ring + side + 1,
            ring + side,
          );
        }
        b.endPart(
          (cx + previousX) * 0.5,
          (cy + previousY) * 0.5,
          (cz + previousZ) * 0.5,
        );
      }

      previousRing = ring;
      previousX = cx;
      previousY = cy;
      previousZ = cz;
    }
  }

  /// Un barreau : deux demi-cylindres opposés et leurs deux billes d'ancrage.
  static void _addRung(MeshBuilder b, int index) {
    final t = (index + 0.5) / rungCount;
    final theta = t * turns * 2 * math.pi;
    final y = (t - 0.5) * height;
    final accent = index % 3 == 0;
    b.group = index;

    for (var side = 0; side < 2; side++) {
      final phi = theta + side * math.pi;
      final ux = math.cos(phi);
      final uz = math.sin(phi);
      b.material = accent ? DnaMaterialId.rungAccent : DnaMaterialId.rungPlain;
      _addRod(b, ux, uz, y);
      b.material = accent ? DnaMaterialId.nodeAccent : DnaMaterialId.nodePlain;
      _addBead(b, ux * radius, y, uz * radius);
    }
  }

  /// Demi-barreau : cylindre radial long de `radius * 0.88`, centré à
  /// `radius * 0.52` de l'axe — il court du jeu central jusqu'au brin.
  static void _addRod(MeshBuilder b, double ux, double uz, double y) {
    final cx = ux * radius * rungOffset;
    final cz = uz * radius * rungOffset;
    final half = radius * rungHalfLength;
    // Repère du cylindre : axe horizontal `u`, montant (0,1,0), et `u × y`.
    final sx = -uz;
    final sz = ux;

    final first = b.vertexCount;
    for (var end = 0; end < 2; end++) {
      final shift = end == 0 ? -half : half;
      for (var i = 0; i <= rungSides; i++) {
        final angle = i / rungSides * 2 * math.pi;
        final c = math.cos(angle);
        final s = math.sin(angle);
        b.addVertex(
          cx + ux * shift + sx * s * rungRadius,
          y + c * rungRadius,
          cz + uz * shift + sz * s * rungRadius,
          sx * s,
          c,
          sz * s,
        );
      }
    }

    b.beginPart();
    const row = rungSides + 1;
    for (var i = 0; i < rungSides; i++) {
      b.addQuad(first + i, first + i + 1, first + row + i + 1, first + row + i);
    }
    // Bouchons plats, comme les faces de `CylinderGeometry`.
    for (var end = 0; end < 2; end++) {
      final shift = end == 0 ? -half : half;
      final sign = end == 0 ? -1.0 : 1.0;
      final centre = b.addVertex(
        cx + ux * shift,
        y,
        cz + uz * shift,
        ux * sign,
        0,
        uz * sign,
      );
      final ringStart = b.vertexCount;
      for (var i = 0; i <= rungSides; i++) {
        final angle = i / rungSides * 2 * math.pi;
        b.addVertex(
          cx + ux * shift + sx * math.sin(angle) * rungRadius,
          y + math.cos(angle) * rungRadius,
          cz + uz * shift + sz * math.sin(angle) * rungRadius,
          ux * sign,
          0,
          uz * sign,
        );
      }
      for (var i = 0; i < rungSides; i++) {
        b.addTriangle(centre, ringStart + i, ringStart + i + 1);
      }
    }
    b.endPart(cx, y, cz);
  }

  /// Bille d'extrémité — sphère basse résolution : elle ne fait qu'une
  /// douzaine de pixels à l'écran.
  static void _addBead(MeshBuilder b, double cx, double cy, double cz) {
    const rings = 6;
    const segments = 8;
    final first = b.vertexCount;
    for (var iy = 0; iy <= rings; iy++) {
      final polar = iy / rings * math.pi;
      final ny = math.cos(polar);
      final ring = math.sin(polar);
      for (var ix = 0; ix <= segments; ix++) {
        final azimuth = ix / segments * 2 * math.pi;
        final nx = ring * math.cos(azimuth);
        final nz = ring * math.sin(azimuth);
        b.addVertex(
          cx + nx * nodeRadius,
          cy + ny * nodeRadius,
          cz + nz * nodeRadius,
          nx,
          ny,
          nz,
        );
      }
    }

    b.beginPart();
    const row = segments + 1;
    for (var iy = 0; iy < rings; iy++) {
      for (var ix = 0; ix < segments; ix++) {
        final a = first + iy * row + ix;
        b.addQuad(a, a + 1, a + row + 1, a + row);
      }
    }
    b.endPart(cx, cy, cz);
  }
}
