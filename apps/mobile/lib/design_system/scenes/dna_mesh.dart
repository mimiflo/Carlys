/// Géométrie de la double hélice d'ADN — portage fidèle de `dna-helix.js`
/// (mode « hero »).
///
/// Le maillage est construit UNE seule fois pour toute l'application : deux
/// brins en TUBE le long d'une courbe hélicoïdale, puis 26 barreaux faits de
/// deux demi-cylindres et de deux billes. Chaque lot de triangles (une
/// « partie ») porte son matériau et son centre local, ce qui permet au peintre
/// de trier en profondeur à chaque image sans jamais retoucher la géométrie.
///
/// Toutes les constantes ci-dessous viennent de la maquette : ce ne sont pas
/// des valeurs visuelles arbitraires mais la définition même de la scène.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Indices des matériaux de la scène ; le peintre tient la table associée.
abstract final class DnaMaterialId {
  /// Brin 1 — violet `0x5B5BF6`.
  static const int strandA = 0;

  /// Brin 2 — violet clair `0x8A8AFA`, déphasé de π.
  static const int strandB = 1;

  /// Barreau lime `0xC6F432`, un sur trois.
  static const int rungAccent = 2;

  /// Barreau blanc à émission violette.
  static const int rungPlain = 3;

  /// Bille lime, au rythme des barreaux accentués.
  static const int nodeAccent = 4;

  /// Bille `0xC9C9FF` à émission violette.
  static const int nodePlain = 5;
}

/// Lot de triangles d'un même matériau, trié en profondeur d'un seul bloc :
/// une bande de tube, un demi-barreau ou une bille.
class DnaPart {
  const DnaPart({
    required this.rung,
    required this.first,
    required this.count,
    required this.cx,
    required this.cy,
    required this.cz,
  });

  /// Indice du barreau propriétaire, ou −1 pour un brin (le barreau respire
  /// avec sa propre phase, le brin suit la respiration globale).
  final int rung;

  /// Plage occupée dans le tableau d'indices du maillage.
  final int first;
  final int count;

  /// Centre local — clef de tri en profondeur.
  final double cx;
  final double cy;
  final double cz;
}

/// Maillage complet de l'hélice, en espace local du groupe `root`.
class DnaMesh {
  DnaMesh._() {
    final builder = _MeshBuilder();
    _addStrand(builder, 0, DnaMaterialId.strandA);
    _addStrand(builder, math.pi, DnaMaterialId.strandB);
    for (var index = 0; index < rungCount; index++) {
      _addRung(builder, index);
    }

    positions = Float32List.fromList(builder.positions);
    normals = Float32List.fromList(builder.normals);
    materials = Uint8List.fromList(builder.materials);
    rungs = Int8List.fromList(builder.rungs);
    indices = Uint16List.fromList(builder.indices);
    parts = List<DnaPart>.unmodifiable(builder.parts);
    vertexCount = positions.length ~/ 3;
  }

  /// Singleton : la construction coûte quelques millisecondes, jamais répétées.
  static final DnaMesh instance = DnaMesh._();

  // --- Constantes de la maquette (mode hero) ---
  static const double radius = 1.32;
  static const double height = 9.4;
  static const double turns = 2.4;
  static const double tubeRadius = 0.082;
  static const int tubeSteps = 180;
  static const int tubeSides = 12;
  static const int rungCount = 26;
  static const double rungRadius = 0.026;
  static const int rungSides = 8;
  static const double nodeRadius = 0.042;

  /// Décalage du demi-barreau depuis le centre (`lerp(mid, end, 0.52)`) et sa
  /// longueur (`len * 0.44`) : c'est ce couple qui ménage le jeu central.
  static const double rungOffset = 0.52;
  static const double rungHalfLength = 0.44;

  late final Float32List positions;
  late final Float32List normals;
  late final Uint8List materials;
  late final Int8List rungs;
  late final Uint16List indices;
  late final List<DnaPart> parts;
  late final int vertexCount;

  /// Phase de respiration de chaque barreau (`t * 4π` dans la maquette).
  static final Float64List rungPhases = Float64List.fromList([
    for (var i = 0; i < rungCount; i++) (i + 0.5) / rungCount * 4 * math.pi,
  ]);

  /// Tampons de travail du peintre, alloués une fois pour toutes.
  late final Float32List screen = Float32List(vertexCount * 2);
  late final Float32List facing = Float32List(vertexCount);
  late final Int32List colors = Int32List(vertexCount);
  late final Uint16List drawOrder = Uint16List(indices.length);
  late final Float64List partDepth = Float64List(parts.length);
  late final List<int> partOrder =
      List<int>.generate(parts.length, (index) => index);

  /// Brin en tube : repère parallèle transporté le long de l'hélice, donc
  /// aucune vrille des anneaux d'un bout à l'autre.
  static void _addStrand(_MeshBuilder b, double phase, int material) {
    b.material = material;
    b.rung = -1;
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
          -1,
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
  static void _addRung(_MeshBuilder b, int index) {
    final t = (index + 0.5) / rungCount;
    final theta = t * turns * 2 * math.pi;
    final y = (t - 0.5) * height;
    final accent = index % 3 == 0;

    for (var side = 0; side < 2; side++) {
      final phi = theta + side * math.pi;
      final ux = math.cos(phi);
      final uz = math.sin(phi);
      b.rung = index;
      b.material = accent ? DnaMaterialId.rungAccent : DnaMaterialId.rungPlain;
      _addRod(b, ux, uz, y, index);
      b.material = accent ? DnaMaterialId.nodeAccent : DnaMaterialId.nodePlain;
      _addBead(b, ux * radius, y, uz * radius, index);
    }
  }

  /// Demi-barreau : cylindre radial de `radius * 0.88`, à `radius * 0.52`
  /// du centre — le jeu central est la liaison hydrogène de la maquette.
  static void _addRod(
    _MeshBuilder b,
    double ux,
    double uz,
    double y,
    int rung,
  ) {
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
        final c = math.cos(angle);
        final s = math.sin(angle);
        b.addVertex(
          cx + ux * shift + sx * s * rungRadius,
          y + c * rungRadius,
          cz + uz * shift + sz * s * rungRadius,
          ux * sign,
          0,
          uz * sign,
        );
      }
      for (var i = 0; i < rungSides; i++) {
        b.addTriangle(centre, ringStart + i, ringStart + i + 1);
      }
    }
    b.endPart(rung, cx, y, cz);
  }

  /// Bille d'extrémité — sphère basse résolution : elle ne fait qu'une
  /// douzaine de pixels à l'écran.
  static void _addBead(
    _MeshBuilder b,
    double cx,
    double cy,
    double cz,
    int rung,
  ) {
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
    b.endPart(rung, cx, cy, cz);
  }
}

/// Accumulateur de sommets et de triangles pendant la construction.
class _MeshBuilder {
  final List<double> positions = <double>[];
  final List<double> normals = <double>[];
  final List<int> materials = <int>[];
  final List<int> rungs = <int>[];
  final List<int> indices = <int>[];
  final List<DnaPart> parts = <DnaPart>[];

  /// Matériau et barreau courants, appliqués aux sommets ajoutés ensuite.
  int material = 0;
  int rung = -1;

  int _partStart = 0;

  int get vertexCount => positions.length ~/ 3;

  int addVertex(
    double px,
    double py,
    double pz,
    double nx,
    double ny,
    double nz,
  ) {
    final index = vertexCount;
    positions
      ..add(px)
      ..add(py)
      ..add(pz);
    normals
      ..add(nx)
      ..add(ny)
      ..add(nz);
    materials.add(material);
    rungs.add(rung);
    return index;
  }

  void addTriangle(int a, int b, int c) {
    indices
      ..add(a)
      ..add(b)
      ..add(c);
  }

  void addQuad(int a, int b, int c, int d) {
    addTriangle(a, b, c);
    addTriangle(a, c, d);
  }

  void beginPart() => _partStart = indices.length;

  void endPart(int rung, double cx, double cy, double cz) {
    parts.add(
      DnaPart(
        rung: rung,
        first: _partStart,
        count: indices.length - _partStart,
        cx: cx,
        cy: cy,
        cz: cz,
      ),
    );
  }
}
