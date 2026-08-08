/// Accumulateur de maillage des scènes 3D.
///
/// Sert à construire, une fois pour toutes, un tampon de sommets unique
/// découpé en « parties » : chaque partie est un lot de triangles partageant
/// un matériau, qui sera trié en profondeur d'un seul bloc au moment du rendu
/// (le rasteriseur logiciel n'a pas de tampon de profondeur).
library;

/// Lot de triangles trié d'un bloc : une bande de tube, un bâtonnet, une bille.
class MeshPart {
  const MeshPart({
    required this.group,
    required this.first,
    required this.count,
    required this.cx,
    required this.cy,
    required this.cz,
  });

  /// Groupe d'animation propriétaire, ou −1 quand la partie suit la scène.
  final int group;

  /// Plage occupée dans le tableau d'indices du maillage.
  final int first;
  final int count;

  /// Centre local — clef de tri en profondeur.
  final double cx;
  final double cy;
  final double cz;
}

/// Construit positions, normales, indices et parties d'un maillage.
class MeshBuilder {
  final List<double> positions = <double>[];
  final List<double> normals = <double>[];
  final List<int> materials = <int>[];
  final List<int> groups = <int>[];
  final List<int> indices = <int>[];
  final List<MeshPart> parts = <MeshPart>[];

  /// Matériau et groupe courants, appliqués aux sommets ajoutés ensuite.
  int material = 0;
  int group = -1;

  int _partStart = 0;

  int get vertexCount => positions.length ~/ 3;

  /// Ajoute un sommet et renvoie son indice.
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
    groups.add(group);
    return index;
  }

  void addTriangle(int a, int b, int c) {
    indices
      ..add(a)
      ..add(b)
      ..add(c);
  }

  /// Quadrilatère en deux triangles. L'orientation n'a pas d'importance :
  /// l'élimination des faces arrière se fait sur la normale, pas sur l'aire.
  void addQuad(int a, int b, int c, int d) {
    addTriangle(a, b, c);
    addTriangle(a, c, d);
  }

  void beginPart() => _partStart = indices.length;

  void endPart(double cx, double cy, double cz) {
    parts.add(
      MeshPart(
        group: group,
        first: _partStart,
        count: indices.length - _partStart,
        cx: cx,
        cy: cy,
        cz: cz,
      ),
    );
  }
}
