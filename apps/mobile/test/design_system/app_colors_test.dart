import 'dart:math' as math;

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde-fous de la palette.
///
/// Une couleur juste à l'œil peut être illisible à la mesure, et un dégradé
/// à trois couleurs peut n'en montrer que deux. Ces deux erreurs ont déjà été
/// commises ici ; ce fichier les empêche de revenir.
void main() {
  /// Luminance relative WCAG 2.1 (§ relative luminance).
  double luminance(Color color) {
    double channel(double value) => value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// Rapport de contraste WCAG entre deux couleurs opaques.
  double contrast(Color a, Color b) {
    final first = luminance(a);
    final second = luminance(b);
    final light = math.max(first, second);
    final dark = math.min(first, second);
    return (light + 0.05) / (dark + 0.05);
  }

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
  });

  group('dégradé de marque', () {
    test('les trois couleurs sont dans l’ordre du logo', () {
      expect(
        AppColors.signature.colors,
        [
          AppColors.signatureStart,
          AppColors.signatureMid,
          AppColors.signatureEnd,
        ],
      );
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
  });

  group('dégradé violet', () {
    test('il s’éclaircit, il ne s’assombrit pas', () {
      final colors = AppColors.violetRamp.colors;
      expect(luminance(colors.last), greaterThan(luminance(colors.first)));
    });

    test('la variante verticale monte vers le clair', () {
      expect(AppColors.violetRampUp.begin, Alignment.bottomCenter);
      expect(AppColors.violetRampUp.end, Alignment.topCenter);
      expect(AppColors.violetRampUp.colors, AppColors.violetRamp.colors);
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
