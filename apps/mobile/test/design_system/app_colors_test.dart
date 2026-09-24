import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';

/// Garde-fous de la palette.
///
/// Une couleur juste à l'œil peut être illisible à la mesure, et un dégradé
/// à trois couleurs peut n'en montrer que deux. Ces deux erreurs ont déjà été
/// commises ici ; ce fichier les empêche de revenir. Les paires que les
/// COMPOSANTS peignent réellement se mesurent dans `contrast_pairs_test.dart`.
void main() {
  /// Les cinq surfaces sombres sur lesquelles du texte peut se poser, de la
  /// plus profonde à la plus claire.
  const darkSurfaces = <String, Color>{
    'darkBackground': AppColors.darkBackground,
    'darkSurface': AppColors.darkSurface,
    'darkSurfaceAlt': AppColors.darkSurfaceAlt,
    'surfaceEngraved': AppColors.surfaceEngraved,
    'surfaceIcon': AppColors.surfaceIcon,
  };

  group('lisibilité sur le fond sombre', () {
    test('le texte principal dépasse largement AAA', () {
      expect(
        contrast(AppColors.darkTextPrimary, AppColors.darkBackground),
        greaterThan(7),
      );
    });

    test('le texte secondaire tient AA (4.5)', () {
      expect(
        contrast(AppColors.darkTextSecondary, AppColors.darkBackground),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('l’accent tient AA, sur le fond comme sous du texte sombre', () {
      // Les deux usages existent : chiffre orange sur le fond, et libellé
      // sombre posé sur un aplat orange (pastille de filtre, sélecteur).
      expect(
        contrast(AppColors.accent, AppColors.darkBackground),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppColors.accent, AppColors.neutral950),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('les gris de texte tiennent AA sur TOUTES les surfaces sombres', () {
      // Le dénominateur d'un total et les libellés de 9 points se posent
      // aussi sur les plaques gravées, plus claires que le fond : c'est donc
      // sur chacune des cinq surfaces que le seuil doit tenir — la boucle
      // est le garde-fou, pas une assertion de plus.
      const textRoles = <String, Color>{
        'textMuted': AppColors.textMuted,
        'darkTextTertiary': AppColors.darkTextTertiary,
      };
      for (final role in textRoles.entries) {
        for (final surface in darkSurfaces.entries) {
          expect(
            contrast(role.value, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: '${role.key} sur ${surface.key}',
          );
        }
      }
    });

    test('l’icône inactive tient le seuil graphique (3:1) partout', () {
      for (final surface in darkSurfaces.entries) {
        expect(
          contrast(AppColors.darkIconInactive, surface.value),
          greaterThanOrEqualTo(3),
          reason: 'darkIconInactive sur ${surface.key}',
        );
      }
    });

    test('deux gris voisins gardent un écart perceptible (>= 1,2:1)', () {
      // Un ordre strict ne suffit pas : une unité de luminance le satisfait
      // sans qu'aucun œil ne la voie. Entre deux rôles voisins on exige un
      // vrai pas — le même rapport que le contraste WCAG, borné à 1,2:1
      // (environ 5 L*).
      double step(Color lighter, Color darker) =>
          (luminance(lighter) + 0.05) / (luminance(darker) + 0.05);
      expect(
        step(AppColors.darkTextSecondary, AppColors.darkTextTertiary),
        greaterThanOrEqualTo(1.2),
        reason: 'secondaire vs tertiaire',
      );
      expect(
        step(AppColors.darkTextTertiary, AppColors.darkIconInactive),
        greaterThanOrEqualTo(1.2),
        reason: 'tertiaire vs icône inactive',
      );
    });

    test('textMuted est l’alias du tertiaire, pas un troisième gris', () {
      // Entre le gris minimal AA sur surfaceIcon et le secondaire, il n'y a
      // pas la place de deux pas perceptibles : trois rôles y devenaient un
      // seul gris à l'œil. La décision est UN gris en retrait — si cette
      // égalité casse, c'est qu'un troisième gris revient : mesurer son
      // écart avant de l'accepter.
      expect(
        identical(AppColors.textMuted, AppColors.darkTextTertiary),
        isTrue,
      );
    });

    test('le violet clair porte du texte, le violet flash non', () {
      // `primaryLight` sert de couleur de texte et de bordure…
      expect(
        contrast(AppColors.primaryLight, AppColors.darkBackground),
        greaterThanOrEqualTo(4.5),
      );
      // …alors que `primaryFlash` ne remplit que des surfaces : sous du blanc
      // il tombe à 3,86, et ce test dit pourquoi il n'a pas le droit d'y aller.
      expect(
        contrast(AppColors.primaryFlash, AppColors.neutral0),
        lessThan(4.5),
      );
    });

    test('le bouton destructif porte son libellé blanc, le rouge d’erreur '
        'non', () {
      // Un libellé de 15 points n'est pas du « grand texte » : il lui faut
      // 4,5. `dangerStrong` remplit le bouton…
      expect(
        contrast(AppColors.dangerStrong, AppColors.neutral0),
        greaterThanOrEqualTo(4.5),
      );
      // …parce que `danger`, sous du blanc, tombe à 3,76 : il reste aux
      // textes et aux icônes d'erreur posés sur le fond sombre.
      expect(contrast(AppColors.danger, AppColors.neutral0), lessThan(4.5));
    });

    test('le violet des libellés blancs tient AA à ses deux bornes', () {
      // Relevé sur la maquette, `ctaStart` valait #A355FC : 3,99:1 sous le
      // blanc. Assombri à teinte et saturation égales, il en tient 4,60, et
      // le dégradé ne fait que s'assombrir jusqu'à `ctaEnd`.
      for (final stop in stopsOf(AppColors.cta)) {
        expect(
          contrast(AppColors.neutral0, stop),
          greaterThanOrEqualTo(wcagText),
          reason: 'blanc sur $stop',
        );
      }
      final start = HSLColor.fromColor(AppColors.ctaStart);
      expect(
        start.hue,
        closeTo(268, 0.5),
        reason: 'même teinte que la maquette',
      );
      expect(
        start.saturation,
        closeTo(0.965, 0.005),
        reason: 'même saturation',
      );
    });
  });

  group('dégradé de marque', () {
    test('les trois couleurs sont dans l’ordre du logo', () {
      expect(AppColors.signature.colors, [
        AppColors.signatureStart,
        AppColors.signatureMid,
        AppColors.signatureEnd,
      ]);
    });

    test('l’orange final occupe une vraie part de la course', () {
      // À parts égales (0, .5, 1), le magenta central tient la moitié du
      // dégradé et l'orange n'apparaît que dans les derniers pixels — mangés
      // par l'arrondi du bouton de bienvenue, qui finissait donc en rose.
      final stops = AppColors.signature.stops;
      expect(stops, isNotNull);
      expect(stops!.last, lessThan(1));
      expect(1 - stops.last, greaterThanOrEqualTo(0.05));
      expect(stops.first, 0);
      // Le violet tient au moins les quatre premiers dixièmes.
      expect(stops[1], greaterThanOrEqualTo(0.4));
    });

    test('elle ne porte AUCUN libellé : ni blanc, ni sombre', () {
      // La preuve que le bouton de bienvenue et les bandeaux de célébration
      // ne pouvaient pas s'en tirer par la seule couleur de leur texte.
      expect(
        contrast(AppColors.neutral0, AppColors.signatureEnd),
        lessThan(wcagText),
      );
      expect(
        contrast(AppColors.onAccent, AppColors.signatureStart),
        lessThan(wcagText),
      );
    });

    test('sa variante sous un texte garde le logo et tient AA partout', () {
      // Mêmes arrêts, même départ ; magenta et orange assombris à teinte et
      // saturation égales.
      expect(AppColors.signatureInk.stops, AppColors.signature.stops);
      expect(AppColors.signatureInk.colors.first, AppColors.signatureStart);
      for (final (ink, logo) in [
        (AppColors.signatureInkMid, AppColors.signatureMid),
        (AppColors.signatureInkEnd, AppColors.signatureEnd),
      ]) {
        final assombri = HSLColor.fromColor(ink);
        final origine = HSLColor.fromColor(logo);
        expect(assombri.hue, closeTo(origine.hue, 0.5), reason: '$ink');
        expect(
          assombri.saturation,
          closeTo(origine.saturation, 0.01),
          reason: '$ink',
        );
        expect(assombri.lightness, lessThan(origine.lightness));
      }
      for (final stop in stopsOf(AppColors.signatureInk)) {
        expect(
          contrast(AppColors.neutral0, stop),
          greaterThanOrEqualTo(wcagText),
          reason: 'blanc sur $stop',
        );
      }
    });
  });

  group('dégradé violet', () {
    test('il s’éclaircit, il ne s’assombrit pas', () {
      final colors = AppColors.violetRamp.colors;
      expect(luminance(colors.last), greaterThan(luminance(colors.first)));
    });
  });

  group('extrémités transparentes', () {
    test('le halo violet s’éteint vers le même violet, pas vers du noir', () {
      // Interpolé canal par canal vers du noir transparent, un halo passe
      // par un violet assombri et désaturé ; vers sa propre teinte à alpha
      // zéro, il garde sa couleur jusqu'à disparaître.
      expect(AppColors.primaryCardClear.a, 0);
      expect(AppColors.primaryCardClear.r, AppColors.primary.r);
      expect(AppColors.primaryCardClear.g, AppColors.primary.g);
      expect(AppColors.primaryCardClear.b, AppColors.primary.b);
      final midway = Color.lerp(
        AppColors.primaryCardStrong,
        AppColors.primaryCardClear,
        0.5,
      )!;
      expect(midway.r, AppColors.primary.r);
      expect(midway.b, AppColors.primary.b);
    });
  });

  group('rose des cœurs', () {
    test('il se distingue franchement de l’accent orange', () {
      // Le rose porte le lien humain, l'orange porte l'action clé : deux
      // rôles, deux couleurs. Trop proches, la distinction ne se verrait
      // pas — la teinte les sépare de plus d'un quart de tour.
      final rose = HSLColor.fromColor(AppColors.affection).hue;
      final orange = HSLColor.fromColor(AppColors.accent).hue;
      expect((rose - orange).abs(), greaterThan(90));
    });

    test('il se lit sur le fond sombre', () {
      // Une icône n'est pas du texte : le seuil est celui des éléments
      // graphiques (AA non textuel, 3:1).
      expect(
        contrast(AppColors.affection, AppColors.darkBackground),
        greaterThan(3),
      );
    });
  });
}
