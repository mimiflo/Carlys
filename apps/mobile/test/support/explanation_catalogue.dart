import 'dart:io';

import 'package:carlys_mobile/core/explanations/explanation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les contrôles que TOUT catalogue d'explications doit passer.
///
/// Ils sont ici et non recopiés parce qu'un second catalogue arrive avec les
/// titres, et qu'un catalogue non relu est un catalogue où l'on oublie une
/// entrée. Le dernier contrôle lit le fichier SOURCE : c'est le seul moyen,
/// sans réflexion, de repérer une explication déclarée mais absente de la
/// liste — elle échapperait sinon à tous les autres contrôles, y compris à
/// ceux qui vérifient qu'elle ne ment pas.
void verifierCatalogue({
  required String nom,
  required File source,
  required List<Explanation> toutes,
}) {
  group('intégrité du catalogue $nom', () {
    test('chaque explication dit ce que c’est ET d’où ça sort', () {
      expect(toutes, isNotEmpty);
      for (final explication in toutes) {
        expect(explication.titre.trim(), isNotEmpty);
        expect(
          explication.cequeCest.trim(),
          isNotEmpty,
          reason: '« ${explication.titre} » n’explique pas ce que c’est.',
        );
        expect(
          explication.douCaSort.trim(),
          isNotEmpty,
          reason: '« ${explication.titre} » ne dit pas d’où ça sort.',
        );
      }
    });

    test('aucun titre en double — l’un cacherait l’autre à l’écran', () {
      final titres = toutes.map((e) => e.titre).toList();
      expect(titres.toSet(), hasLength(titres.length));
    });

    test('aucune explication déclarée n’est oubliée dans `toutes`', () {
      expect(
        source.existsSync(),
        isTrue,
        reason: 'Source introuvable depuis apps/mobile : ${source.path}',
      );
      final code = source.readAsStringSync();

      final declarees = RegExp(
        r'static const Explanation (\w+) =',
      ).allMatches(code).map((m) => m.group(1)!).toList();
      expect(
        declarees,
        isNotEmpty,
        reason: '$nom ne déclare plus aucune explication.',
      );

      final liste = RegExp(r'toutes = \[([^\]]*)\]').firstMatch(code)?.group(1);
      expect(liste, isNotNull, reason: 'La liste `toutes` a disparu de $nom.');

      final listees = liste!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();

      expect(
        listees,
        containsAll(declarees),
        reason:
            'Une explication déclarée manque à `toutes` : elle échapperait '
            'à TOUS les contrôles de ce fichier.',
      );
      expect(toutes, hasLength(declarees.length));
    });
  });
}
