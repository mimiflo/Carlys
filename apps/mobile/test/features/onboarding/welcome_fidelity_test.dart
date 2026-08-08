import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
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
/// Petits calculs de mise en page, refaits ici pour ne pas dupliquer les
/// constantes de l'écran.
abstract final class AthleteFramingHelpers {
  static double textWidth(Size screen) =>
      WelcomeScreen.textWidthFactor * (screen.width - 2 * AppSpacing.gutter);
}

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

  group('cadrage de la photographie', () {
    // Le cadrage est exprimé en fractions d'écran : on l'interroge donc avec
    // la taille de l'écran, pas celle du cadre.
    (double, double) windowFor(Size screen) =>
        AthletePhotoFraming.windowFor(screen);

    // « Le logo dans le dos de l'athlète doit rester visible » — SPEC.md, §6.
    // La spécification donne aussi un cadrage fixe (22 %), relevé sur une
    // planche large ; sur un téléphone il laisse le logo hors champ. C'est
    // l'exigence qui prime, pas le chiffre — d'où un cadrage recalculé, et ce
    // test sur les tailles d'écran réelles plutôt que sur une seule.
    for (final (name, screen) in const [
      ('iPhone SE', Size(375, 667)),
      ('petit Android', Size(360, 640)),
      ('iPhone 15', Size(393, 852)),
      ('grand Android', Size(412, 915)),
      ('pliable ouvert', Size(600, 900)),
    ]) {
      test('le logo dorsal reste visible — $name', () {
        final (left, right) = windowFor(screen);
        expect(
          left,
          lessThanOrEqualTo(AthletePhotoFraming.markLeft),
          reason: 'le logo est coupé à gauche',
        );
        expect(
          right,
          greaterThanOrEqualTo(AthletePhotoFraming.markRight),
          reason: 'le logo est coupé à droite',
        );
      });
    }

    test('la personne passe DERRIÈRE le texte, elle ne s’arrête pas devant',
        () {
      // Ce test a d'abord affirmé le contraire — que le fondu devait être
      // éteint partout où le texte s'écrit. C'était une erreur de lecture : à
      // ce compte, la photographie disparaissait aux deux tiers et n'était
      // plus un grand élément de fond mais une vignette confinée à droite.
      // La lisibilité vient de la PLAQUE SOMBRE et du voile horizontal, pas de
      // l'effacement de la personne.
      const screen = Size(393, 852);
      final textRight =
          (AppSpacing.gutter + AthleteFramingHelpers.textWidth(screen)) /
              screen.width;
      expect(AthletePhotoFraming.fadeFrom, lessThan(textRight));
    });

    test('le cadrage reste un portrait, pas un gros plan', () {
      // Le défaut d'origine : `cover` dans une boîte étroite ET pleine hauteur
      // ne gardait que 43 % de la largeur du cliché — la personne devenait un
      // buste, et le logo dorsal sortait du cadre. On exige d'en montrer plus
      // de la moitié. Les bras restent rognés sur les bords, comme sur la
      // planche validée où la page coupe aussi le bras droit.
      final (left, right) = windowFor(const Size(393, 852));
      final shown = (right - left) / AthletePhotoFraming.source.width;
      expect(shown, closeTo(AthletePhotoFraming.shownWidth, 0.01));
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
