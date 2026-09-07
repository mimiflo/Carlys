import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LA LIGNE ÉDITORIALE, tenue par un test plutôt que par la relecture.
///
/// Deux règles, écrites dans CLAUDE.md et jusqu'ici défendues par personne :
/// l'application TUTOIE, et ses textes visibles n'emploient pas le tiret
/// cadratin — il fait « machine ». `academy_pack_test.dart` fait déjà ce
/// travail, mais pour le seul pack de leçons : les 200 écrans du dossier
/// `lib/` n'avaient aucun filet, et sept vouvoiements ainsi que six cadratins
/// de prose s'y étaient installés.
///
/// Le balayage porte sur les LITTÉRAUX DE CHAÎNE, commentaires retirés :
/// c'est là, et là seulement, que vit le texte affiché. Une prose de
/// commentaire ou de documentation garde donc sa liberté de ponctuation.
void main() {
  test('aucun texte affiché ne vouvoie', () {
    final fautes = <String>[];
    for (final fichier in _fichiersDart()) {
      for (final literal in dartStringLiterals(
        File(fichier).readAsStringSync(),
      )) {
        // « rendez-vous » est un NOM, pas un vouvoiement : trois citations du
        // jour et une valeur de marque l'emploient à bon droit.
        final texte = literal.text.replaceAll(
          RegExp('rendez-vous', caseSensitive: false),
          '',
        );
        if (RegExp(
          r'\b(vous|votre|vos)\b',
          caseSensitive: false,
        ).hasMatch(texte)) {
          fautes.add('$fichier:${literal.line} : « ${literal.text} »');
        }
      }
    }
    expect(
      fautes,
      isEmpty,
      reason:
          'Carlys tutoie. Réécris ces textes à la deuxième personne du '
          'singulier :\n${fautes.join('\n')}',
    );
  });

  test('aucun texte affiché ne porte de tiret de ponctuation', () {
    final fautes = <String>[];
    for (final fichier in _fichiersDart()) {
      for (final literal in dartStringLiterals(
        File(fichier).readAsStringSync(),
      )) {
        final texte = literal.text;
        // SEULE exception : le cadratin SEUL, marque de valeur absente
        // (« — » dans une cellule sans donnée). Ce n'est pas de la prose,
        // c'est un glyphe de tableau, et douze écrans s'en servent.
        if (texte.trim() == '—') {
          continue;
        }
        if (texte.contains('—') ||
            texte.contains('–') ||
            texte.contains(' - ')) {
          fautes.add('$fichier:${literal.line} : « $texte »');
        }
      }
    }
    expect(
      fautes,
      isEmpty,
      reason:
          'Les tirets de ponctuation font « machine ». Un deux-points, une '
          'virgule ou un point les remplacent :\n${fautes.join('\n')}',
    );
  });

  // Un garde-fou qui lit mal ne garde rien : le lecteur de littéraux est
  // lui-même éprouvé, sur les formes que le dépôt emploie vraiment.
  group('le lecteur de littéraux', () {
    test('ignore les commentaires', () {
      const source = '''
// Ce commentaire vouvoie : vos séances — et personne ne s'en émeut.
/* Celui-ci aussi — votre bloc. /* imbriqué : vous */ toujours dedans. */
const a = 'texte propre';
''';
      expect(dartStringLiterals(source).map((l) => l.text), ['texte propre']);
    });

    test('ne prend pas une apostrophe de commentaire pour une chaîne', () {
      const source = '''
// L'accueil n'a pas de total à lui.
const a = 'après le commentaire';
''';
      expect(dartStringLiterals(source).map((l) => l.text), [
        'après le commentaire',
      ]);
    });

    test('ne voit pas de commentaire dans une chaîne', () {
      const source = "const a = 'https://carlys.app/a — b';";
      expect(dartStringLiterals(source).map((l) => l.text), [
        'https://carlys.app/a — b',
      ]);
    });

    test('sort du texte à chaque interpolation', () {
      // La forme exacte de `title_summary.dart` : le cadratin y est un
      // littéral À PART, imbriqué dans l'interpolation — il doit être lu
      // comme tel, sinon la règle du marqueur seul ne le reconnaît pas.
      const source = r"""
const a = '${opened ? profile.points : '—'} / $maxTotal';
""";
      expect(dartStringLiterals(source).map((l) => l.text), ['—', ' / ']);
    });

    test('lit les chaînes brutes, triples et adjacentes', () {
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

    test('rend la ligne où la chaîne s’ouvre', () {
      const source = '''
const a = 1;
const b = 'deuxième ligne';
''';
      expect(dartStringLiterals(source).single.line, 2);
    });
  });
}

/// Tous les fichiers Dart écrits à la main sous `lib/`.
Iterable<String> _fichiersDart() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        // Le code engendré (Drift) n'est pas de notre plume.
        !entity.path.endsWith('.g.dart')) {
      yield entity.path;
    }
  }
}

/// Un littéral de chaîne et la ligne où il s'ouvre.
class DartStringLiteral {
  const DartStringLiteral(this.line, this.text);

  final int line;
  final String text;
}

/// Les littéraux de chaîne d'une source Dart, commentaires retirés.
///
/// Le contenu d'une interpolation `${…}` est du CODE : il est parcouru comme
/// tel, et les chaînes qu'il ouvre ressortent comme des littéraux à part
/// entière. Les séquences d'échappement et les `$identifiant` ne sont pas
/// interprétés — ils ne portent jamais de prose.
List<DartStringLiteral> dartStringLiterals(String source) {
  final literals = <DartStringLiteral>[];
  final pile = <Object>[];
  var ligne = 1;
  var i = 0;

  while (i < source.length) {
    final sommet = pile.isEmpty ? null : pile.last;

    if (sommet is _StringFrame) {
      final char = source[i];
      if (char == '\n') {
        ligne++;
        sommet.text.write(char);
        i++;
      } else if (!sommet.raw && char == r'\' && i + 1 < source.length) {
        // Un caractère échappé n'est ni un délimiteur, ni de la ponctuation
        // visible : on le remplace par une espace, qui ne déclenche rien.
        if (source[i + 1] == '\n') ligne++;
        sommet.text.write(' ');
        i += 2;
      } else if (!sommet.raw &&
          char == r'$' &&
          i + 1 < source.length &&
          source[i + 1] == '{') {
        pile.add(_InterpolationFrame());
        i += 2;
      } else if (!sommet.raw && char == r'$') {
        i++;
        while (i < source.length && _identifiant.hasMatch(source[i])) {
          i++;
        }
      } else if (char == sommet.quote &&
          (!sommet.triple || source.startsWith(sommet.quote * 3, i))) {
        literals.add(DartStringLiteral(sommet.line, sommet.text.toString()));
        pile.removeLast();
        i += sommet.triple ? 3 : 1;
      } else {
        sommet.text.write(char);
        i++;
      }
      continue;
    }

    // Mode CODE (racine, ou intérieur d'une interpolation).
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (source.startsWith('/*', i)) {
      // Les commentaires de bloc s'imbriquent en Dart.
      var profondeur = 1;
      i += 2;
      while (i < source.length && profondeur > 0) {
        if (source.startsWith('/*', i)) {
          profondeur++;
          i += 2;
        } else if (source.startsWith('*/', i)) {
          profondeur--;
          i += 2;
        } else {
          if (source[i] == '\n') ligne++;
          i++;
        }
      }
      continue;
    }

    final raw =
        source[i] == 'r' &&
        i + 1 < source.length &&
        _estGuillemet(source[i + 1]);
    final debut = raw ? i + 1 : i;
    if (_estGuillemet(source[debut])) {
      final quote = source[debut];
      final triple = source.startsWith(quote * 3, debut);
      pile.add(
        _StringFrame(quote: quote, triple: triple, raw: raw, line: ligne),
      );
      i = debut + (triple ? 3 : 1);
      continue;
    }

    if (source[i] == '\n') ligne++;
    if (sommet is _InterpolationFrame) {
      if (source[i] == '{') {
        sommet.profondeur++;
      } else if (source[i] == '}') {
        sommet.profondeur--;
        if (sommet.profondeur == 0) pile.removeLast();
      }
    }
    i++;
  }

  return literals;
}

final RegExp _identifiant = RegExp(r'[A-Za-z0-9_]');

bool _estGuillemet(String char) => char == "'" || char == '"';

/// Une chaîne en cours de lecture.
class _StringFrame {
  _StringFrame({
    required this.quote,
    required this.triple,
    required this.raw,
    required this.line,
  });

  final String quote;
  final bool triple;
  final bool raw;
  final int line;
  final StringBuffer text = StringBuffer();
}

/// Une interpolation `${…}` : du code, jusqu'à l'accolade qui la ferme.
class _InterpolationFrame {
  int profondeur = 1;
}
