import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LES GLYPHES DES MÉDAILLONS sont pleins.
///
/// Le bloc « Popups » d'`app_icons.dart` le dit en tête : « des glyphes
/// pleins et sans cercle quand c'est possible : le médaillon EST déjà le
/// cercle ». Un glyphe en trait y paraît maigre, seul de sa famille ; la
/// corbeille de chaque confirmation de suppression l'a été, trois lignes
/// sous la règle. Un glyphe en trait n'y entre donc qu'avec son exception
/// écrite (« Exception : »), dans le commentaire de son nom.
///
/// La règle se lit dans la SOURCE : une `IconData` ne dit pas si elle est
/// pleine ou en trait, son nom Material, si.
void main() {
  test('chaque glyphe en trait du bloc Popups justifie son exception', () {
    final source = File(
      'lib/design_system/icons/app_icons.dart',
    ).readAsStringSync();
    final start = source.indexOf('// ── Popups');
    expect(start, isNot(-1), reason: 'le bloc « Popups » a disparu');
    final rest = source.substring(start + 1);
    final next = rest.indexOf('// ──');
    final block = next == -1 ? rest : rest.substring(0, next);

    final declaration = RegExp(
      r'((?:[ \t]*///[^\n]*\n)*)[ \t]*static const IconData (\w+)\s*=\s*'
      r'Icons\.(\w+);',
    );
    final names = <String>[];
    for (final match in declaration.allMatches(block)) {
      final (doc, name, glyph) = (match[1]!, match[2]!, match[3]!);
      names.add(name);
      if (glyph.contains('outline')) {
        expect(
          doc,
          contains('Exception :'),
          reason:
              '$name = Icons.$glyph : glyphe en trait, sans exception écrite',
        );
      }
    }
    // Le bloc a bien été lu : une expression régulière qui ne trouve plus
    // rien rendrait ce test vert pour de mauvaises raisons.
    expect(names, containsAll(<String>['noticeInfo', 'confirmDelete']));
  });
}
