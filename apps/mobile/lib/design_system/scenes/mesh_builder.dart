/// Accumulateur de maillage des scènes 3D.
///
/// Sert à construire, une fois pour toutes, un tampon de sommets unique :
/// positions, normales, matériau et groupe d'animation par sommet, plus les
/// indices des triangles.
///
/// IL N'Y A PLUS DE « PARTIES ». Le maillage était aussi découpé en lots de
/// triangles (`MeshPart`), chacun portant son centre, pour un tri en
/// profondeur par lot au moment du rendu. Personne ne lisait ces lots : le
/// peintre trie TRIANGLE PAR TRIANGLE, et son commentaire explique pourquoi
/// un tri par lot ne suffirait pas (deux lots qui s'entrecroisent se
/// départageraient en bloc, et l'on verrait une bille passer devant un brin
/// qui devrait la masquer). La machinerie survivait à l'approche qu'elle
/// servait.
library;

/// Construit positions, normales et indices d'un maillage.
class MeshBuilder {
  final List<double> positions = <double>[];
  final List<double> normals = <double>[];
  final List<int> materials = <int>[];
  final List<int> groups = <int>[];
  final List<int> indices = <int>[];

  /// Matériau et groupe courants, appliqués aux sommets ajoutés ensuite.
  int material = 0;
  int group = -1;

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
}
