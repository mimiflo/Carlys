import 'package:carlys_mobile/features/onboarding/presentation/widgets/brand_manifesto.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/welcome_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fidélité de la page de marque au design validé.
///
/// Trois pièges de traduction CSS → Flutter ont chacun produit un rendu FAUX
/// mais crédible. Ils sont verrouillés ici, parce qu'un œil ne les rattrape
/// pas : la page reste jolie quand ils reviennent, elle cesse simplement
/// d'être la maquette.
void main() {
  group('accroche en relief', () {
    testWidgets('la perspective RAPPROCHE le texte au lieu de l’éloigner',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Align(child: BrandClaim())),
        ),
      );

      final transform =
          tester.widget<Transform>(find.byType(Transform).first).transform;

      // Un point à droite de l'origine doit ressortir AGRANDI : c'est tout
      // l'effet recherché. Avec le signe de perspective de l'idiome Flutter
      // habituel (+1/d au lieu du -1/d de CSS), il rétrécissait — l'accroche
      // perdait 11 % de largeur sans que rien n'ait l'air cassé.
      final projected =
          MatrixUtils.transformPoint(transform, const Offset(200, 0));
      expect(projected.dx, greaterThan(200));
    });

    testWidgets('l’extrusion s’éclaircit vers les lettres', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Align(child: BrandClaim())),
        ),
      );

      final shadows =
          tester.widget<Text>(find.byType(Text).first).style!.shadows!;

      // CSS empile les `text-shadow` de haut en bas, Flutter les peint dans
      // l'ordre : la liste est donc à l'envers de la référence. Recopiée telle
      // quelle, la teinte la plus sombre recouvrait les autres et le relief
      // virait au noir. La dernière peinte — donc la plus haute — est la plus
      // claire, et la plus proche des lettres.
      final last = shadows.last;
      expect(last.offset, const Offset(1, 1));
      for (final other in shadows.take(shadows.length - 1)) {
        expect(
          last.color.computeLuminance(),
          greaterThan(other.color.computeLuminance()),
        );
      }
    });
  });

  testWidgets('les halos du décor sont ELLIPTIQUES, pas circulaires',
      (tester) async {
    // Flutter dessine un dégradé radial CIRCULAIRE (rayon × plus petit côté)
    // là où CSS inscrit une ellipse dans la boîte. Sans correction, un halo
    // posé dans un cadre allongé se contracte en pastille.
    const bounds = Rect.fromLTWH(0, 0, 300, 900);
    final matrix = const EllipticGradient(0.5, 0.5).transform(bounds);

    // Le cercle de base a pour rayon 0.5 × plus petit côté = 150. Pour que
    // l'ellipse touche les bords il faut donc 150 en x (facteur 1) et 450 en y
    // (facteur 3) : l'axe long est bien étiré, l'axe court intact.
    expect(matrix.entry(0, 0), closeTo(1, 0.001));
    expect(matrix.entry(1, 1), closeTo(3, 0.001));
  });
}
