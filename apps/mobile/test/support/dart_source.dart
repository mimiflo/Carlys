/// LIRE UNE SOURCE DART SANS ANALYSEUR : les chaînes d'un côté, le code de
/// l'autre.
///
/// Deux tests-balais s'appuient sur cette lecture, et tous deux ont besoin de
/// la MÊME distinction. `editorial_tone_test.dart` inspecte les LITTÉRAUX —
/// c'est là, et là seulement, que vit le texte affiché.
/// `raw_colors_test.dart` inspecte le CODE — c'est là que vivent les
/// couleurs. Une prose de commentaire garde donc sa liberté dans les deux
/// cas, et une couleur citée en commentaire n'invente pas une faute.
///
/// Le contenu d'une interpolation `${…}` est du CODE : il est parcouru comme
/// tel, les chaînes qu'il ouvre ressortent comme des littéraux à part
/// entière, et les couleurs qu'il nomme restent visibles au balai. Les
/// séquences d'échappement et les `$identifiant` ne sont pas interprétés —
/// ils ne portent jamais de prose.
library;

/// Un littéral de chaîne et la ligne où il s'ouvre.
class DartStringLiteral {
  const DartStringLiteral(this.line, this.text);

  final int line;
  final String text;
}

/// Une source lue : ses littéraux d'un côté, son code seul de l'autre.
class DartSource {
  const DartSource({required this.literals, required this.code});

  final List<DartStringLiteral> literals;

  /// La source privée de ses commentaires ET du contenu de ses chaînes, tous
  /// remplacés par des espaces. Les sauts de ligne sont conservés : la
  /// n-ième ligne du code reste la n-ième ligne du fichier, et une faute se
  /// cite donc à sa vraie place.
  final String code;
}

/// Les littéraux de chaîne d'une source Dart, commentaires retirés.
List<DartStringLiteral> dartStringLiterals(String source) =>
    readDartSource(source).literals;

/// Le code d'une source Dart, commentaires et texte des chaînes retirés.
String dartCode(String source) => readDartSource(source).code;

/// Sépare, en UNE passe, les chaînes du code.
DartSource readDartSource(String source) {
  final literals = <DartStringLiteral>[];
  final code = StringBuffer();
  final pile = <Object>[];
  var ligne = 1;
  var i = 0;

  /// Ce qui n'est pas du code garde sa place, sans son contenu : une espace
  /// par caractère, un saut de ligne pour un saut de ligne.
  void masquer(String texte) {
    for (final unite in texte.split('')) {
      code.write(unite == '\n' ? '\n' : ' ');
    }
  }

  while (i < source.length) {
    final sommet = pile.isEmpty ? null : pile.last;

    if (sommet is _StringFrame) {
      final char = source[i];
      if (char == '\n') {
        ligne++;
        sommet.text.write(char);
        code.write('\n');
        i++;
      } else if (!sommet.raw && char == r'\' && i + 1 < source.length) {
        // Un caractère échappé n'est ni un délimiteur, ni de la ponctuation
        // visible : on le remplace par une espace, qui ne déclenche rien.
        if (source[i + 1] == '\n') ligne++;
        sommet.text.write(' ');
        masquer(source.substring(i, i + 2));
        i += 2;
      } else if (!sommet.raw &&
          char == r'$' &&
          i + 1 < source.length &&
          source[i + 1] == '{') {
        pile.add(_InterpolationFrame());
        masquer(r'${');
        i += 2;
      } else if (!sommet.raw && char == r'$') {
        final debut = i;
        i++;
        while (i < source.length && _identifiant.hasMatch(source[i])) {
          i++;
        }
        masquer(source.substring(debut, i));
      } else if (char == sommet.quote &&
          (!sommet.triple || source.startsWith(sommet.quote * 3, i))) {
        literals.add(DartStringLiteral(sommet.line, sommet.text.toString()));
        pile.removeLast();
        final longueur = sommet.triple ? 3 : 1;
        masquer(source.substring(i, i + longueur));
        i += longueur;
      } else {
        sommet.text.write(char);
        code.write(' ');
        i++;
      }
      continue;
    }

    // Mode CODE (racine, ou intérieur d'une interpolation).
    if (source.startsWith('//', i)) {
      final debut = i;
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      masquer(source.substring(debut, i));
      continue;
    }
    if (source.startsWith('/*', i)) {
      // Les commentaires de bloc s'imbriquent en Dart.
      final debut = i;
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
      masquer(source.substring(debut, i));
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
      final fin = debut + (triple ? 3 : 1);
      masquer(source.substring(i, fin));
      i = fin;
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
    code.write(source[i]);
    i++;
  }

  return DartSource(literals: literals, code: code.toString());
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
