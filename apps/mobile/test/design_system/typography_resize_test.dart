/// Redimensionner un style ne doit pas laisser l'interlettrage derrière.
///
/// `letterSpacingEm` est RELATIF dans `tokens.json` ; Flutter le stocke en
/// points ABSOLUS. `AppTypography.labelMono.copyWith(fontSize: 8)` garde donc
/// le 1,2 calculé pour 10 points — 15 % trop lâche —, et à 12 points il est
/// 17 % trop serré. Sur des étiquettes en capitales monospace, là où
/// l'interlettrage compte le plus, cela se voit.
///
/// `AppTypography.resized` remet la proportion. Ce contrôle existe parce que
/// la fonction a été écrite, documentée… et employée zéro fois :
/// cinquante-trois redimensionnements continuaient de passer par `copyWith`.
///
/// Il ne reproche QUE l'oubli. Un `letterSpacing:` posé à la main dans le même
/// appel remplace la valeur d'origine au lieu de la laisser derrière : les
/// signatures de marque, qui mettent le corps et l'interlettrage à l'échelle
/// ensemble, sont donc en règle sans passer par `resized`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aucun style à interlettrage n’est redimensionné par copyWith', () {
    // Les styles dont `letterSpacing` n'est pas nul — les seuls que la
    // dérivation peut abîmer. Les autres n'ont rien à rééchelonner.
    const avecInterlettrage = <String>{
      'display',
      'pageTitle',
      'title',
      'heading',
      'subheading',
      'metricXL',
      'metricL',
      'metricM',
      'quote',
      'labelMono',
      'headline',
      'subtitle',
      'metric',
    };

    final fautifs = <String>[];
    final debut = RegExp(r'AppTypography\.([A-Za-z][A-Za-z0-9]*)\.copyWith\(');
    for (final fichier in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!fichier.path.endsWith('.dart') ||
          fichier.path.endsWith('app_typography.dart')) {
        continue;
      }
      final source = fichier.readAsStringSync();
      for (final m in debut.allMatches(source)) {
        final style = m.group(1)!;
        if (!avecInterlettrage.contains(style)) continue;
        final fin = _finParenthese(source, m.end - 1);
        if (fin == null) continue;
        final arguments = source.substring(m.end, fin);
        if (!arguments.contains('fontSize:')) continue;
        // Un `letterSpacing:` POSÉ À LA MAIN dans le même appel n'oublie
        // rien : il remplace la valeur d'origine au lieu de la laisser
        // derrière. C'est le cas des signatures de marque, qui mettent le
        // corps ET l'interlettrage à l'échelle ensemble. Ce qui est
        // reproché ici, c'est l'oubli — pas la dérivation.
        if (arguments.contains('letterSpacing:')) continue;
        final ligne = '\n'.allMatches(source.substring(0, m.start)).length + 1;
        fautifs.add(
          '${fichier.path}:$ligne → AppTypography.$style.copyWith(fontSize:)',
        );
      }
    }

    expect(
      fautifs,
      isEmpty,
      reason:
          'Redimensionner par copyWith laisse l’interlettrage de la taille '
          'd’origine. Employer AppTypography.resized(AppTypography.<style>, '
          '<taille>), puis .copyWith() pour le reste :\n  - '
          '${fautifs.join('\n  - ')}',
    );
  });
}

/// Index de la parenthèse fermant celle ouverte à [ouvrante], chaînes ignorées.
int? _finParenthese(String source, int ouvrante) {
  var profondeur = 0;
  String? guillemet;
  for (var i = ouvrante; i < source.length; i++) {
    final c = source[i];
    if (guillemet != null) {
      if (c == r'\') {
        i++;
      } else if (c == guillemet) {
        guillemet = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      guillemet = c;
    } else if (c == '(') {
      profondeur++;
    } else if (c == ')') {
      profondeur--;
      if (profondeur == 0) return i;
    }
  }
  return null;
}
