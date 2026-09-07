/// Lecture des directives `import` / `export` des sources du paquet.
///
/// Volontairement textuelle : résoudre le graphe d'imports ne demande pas
/// d'analyseur, et un test d'architecture qui aurait besoin de charger
/// `analyzer` mettrait des dizaines de secondes là où quelques millisecondes
/// suffisent. Le prix de ce choix est dit sous [readDartImports].
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Une directive lue dans un fichier source, avec de quoi la citer.
class DartImport {
  const DartImport({
    required this.file,
    required this.line,
    required this.uri,
    required this.target,
  });

  /// Chemin du fichier IMPORTANT, relatif à la racine du paquet, en `/`.
  final String file;

  /// Numéro de ligne, à partir de 1 — pour un message « fichier:ligne ».
  final int line;

  /// L'URI telle qu'elle est écrite dans le source.
  final String uri;

  /// Chemin visé DANS le paquet (`lib/...`), ou `null` si la cible est
  /// extérieure : `dart:`, ou un autre paquet du pub.
  final String? target;

  /// « fichier:ligne → cible », la forme attendue dans un échec.
  @override
  String toString() => '$file:$line → $uri';
}

const String _packagePrefix = 'package:carlys_mobile/';

/// Chemin visé, relatif à la racine du paquet, ou `null` hors du paquet.
String? _resolve(String importerPath, String uri) {
  if (uri.startsWith(_packagePrefix)) {
    return p.posix.normalize('lib/${uri.substring(_packagePrefix.length)}');
  }
  if (uri.contains(':')) return null; // dart:… ou package:autre_chose/…
  return p.posix.normalize(p.posix.join(p.posix.dirname(importerPath), uri));
}

/// Une directive de compilation, ancrée en colonne 0 comme `dart format` les
/// laisse toujours — ce qui écarte au passage les chaînes de caractères
/// contenant le mot « import » à l'intérieur d'un corps de fonction.
final RegExp _directive = RegExp('''^(?:import|export)\\s+['"]([^'"]+)['"]''');

/// Toutes les directives des fichiers `.dart` sous [directory], donné
/// relativement à la racine du paquet (le répertoire courant sous
/// `flutter test`).
///
/// Les fichiers engendrés (`*.g.dart`) sont ignorés : ce n'est pas nous qui
/// les écrivons, et une règle d'architecture ne s'applique qu'au code écrit.
///
/// Limite assumée de l'approche textuelle : une directive dont l'URI serait
/// écrite sur la ligne suivante échapperait à la lecture. `dart format`, qui
/// tourne en CI, ne produit jamais cette forme.
List<DartImport> readDartImports(String directory) {
  final root = Directory(directory);
  if (!root.existsSync()) {
    throw StateError(
      'Répertoire introuvable : $directory. Les tests doivent tourner depuis '
      'la racine du paquet (apps/mobile), ce que fait `flutter test`.',
    );
  }

  final imports = <DartImport>[];
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('.g.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final path = p.posix.joinAll(p.split(p.relative(file.path)));
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final match = _directive.firstMatch(lines[index]);
      if (match == null) continue;
      final uri = match.group(1)!;
      imports.add(
        DartImport(
          file: path,
          line: index + 1,
          uri: uri,
          target: _resolve(path, uri),
        ),
      );
    }
  }
  return imports;
}
