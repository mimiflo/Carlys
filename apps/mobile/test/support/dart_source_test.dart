import 'package:flutter_test/flutter_test.dart';

import 'dart_source.dart';

/// UN GARDE-FOU QUI LIT MAL NE GARDE RIEN.
///
/// Deux tests-balais lisent le dépôt à travers ce module : la ligne
/// éditoriale inspecte les CHAÎNES (`editorial_tone_test.dart`), les couleurs
/// brutes inspectent le CODE (`raw_colors_test.dart`). Une lecture fausse
/// rendrait les deux muets sans que rien ne rougisse — le lecteur est donc
/// éprouvé lui-même, sur les formes que le dépôt emploie vraiment.
void main() {
  group('les chaînes', () {
    test('ignorent les commentaires', () {
      const source = '''
// Ce commentaire vouvoie : vos séances — et personne ne s'en émeut.
/* Celui-ci aussi — votre bloc. /* imbriqué : vous */ toujours dedans. */
const a = 'texte propre';
''';
      expect(dartStringLiterals(source).map((l) => l.text), ['texte propre']);
    });

    test('ne prennent pas une apostrophe de commentaire pour une chaîne', () {
      const source = '''
// L'accueil n'a pas de total à lui.
const a = 'après le commentaire';
''';
      expect(dartStringLiterals(source).map((l) => l.text), [
        'après le commentaire',
      ]);
    });

    test('ne voient pas de commentaire dans une chaîne', () {
      const source = "const a = 'https://carlys.app/a — b';";
      expect(dartStringLiterals(source).map((l) => l.text), [
        'https://carlys.app/a — b',
      ]);
    });

    test('sortent du texte à chaque interpolation', () {
      // La forme exacte de `title_summary.dart` : le cadratin y est un
      // littéral À PART, imbriqué dans l'interpolation — il doit être lu
      // comme tel, sinon la règle du marqueur seul ne le reconnaît pas.
      const source = r"""
const a = '${opened ? profile.points : '—'} / $maxTotal';
""";
      expect(dartStringLiterals(source).map((l) => l.text), ['—', ' / ']);
    });

    test('lisent les chaînes brutes, triples et adjacentes', () {
      const source = r"""
const a = r'brut \n intact';
const b = '''
sur
deux lignes''';
const c = 'première '
    'seconde';
""";
      expect(dartStringLiterals(source).map((l) => l.text), [
        r'brut \n intact',
        '\nsur\ndeux lignes',
        'première ',
        'seconde',
      ]);
    });

    test('rendent la ligne où la chaîne s’ouvre', () {
      const source = '''
const a = 1;
const b = 'deuxième ligne';
''';
      expect(dartStringLiterals(source).single.line, 2);
    });
  });

  group('le code', () {
    test('perd ses commentaires, de ligne comme de bloc', () {
      const source = '''
// color: Colors.red
const a = 1; /* Color(0xFFAABBCC) */
''';
      expect(dartCode(source), isNot(contains('Colors.red')));
      expect(dartCode(source), isNot(contains('Color(0x')));
      expect(dartCode(source), contains('const a = 1;'));
    });

    test('perd le texte de ses chaînes, guillemets compris', () {
      const source = "const a = 'Color(0xFF0000) et Colors.red';";
      expect(dartCode(source), isNot(contains('Color')));
      expect(dartCode(source), contains('const a = '));
    });

    test('garde le code d’une interpolation', () {
      // Le contenu d'une `${…}` est du CODE : une couleur y est aussi brute
      // qu'ailleurs, et le balai doit continuer de la voir.
      const source = r"const a = 'teinte ${Colors.red} fin';";
      expect(dartCode(source), contains('Colors.red'));
      expect(dartCode(source), isNot(contains('teinte')));
    });

    test('garde la géométrie du fichier, ligne pour ligne', () {
      // Sans quoi une faute serait citée à la mauvaise ligne : le contenu
      // masqué rend des espaces, jamais rien de plus court.
      const source = '''
// un commentaire
const a = 'chaîne';
const b = Colors.red;
''';
      final lignes = dartCode(source).split('\n');
      expect(lignes.length, source.split('\n').length);
      expect(lignes[2], contains('Colors.red'));
      expect(lignes[0].trim(), isEmpty);
    });
  });
}
