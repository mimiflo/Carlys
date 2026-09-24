import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// MESURER UN CONTRASTE, et non le regarder.
///
/// Les formules de WCAG 2.2 (§ relative luminance, § contrast ratio), en un
/// seul endroit : `app_colors_test.dart` et `app_popup_test.dart` les
/// recopiaient chacun à la main. Et une lecture de widget, [inkFailuresOn],
/// qui mesure tout ce qui s'écrit sur une surface colorée.

/// Seuil d'un texte de taille normale (WCAG 1.4.3, AA).
const double wcagText = 4.5;

/// Seuil d'une icône ou d'un graphique porteur de sens (WCAG 1.4.11).
const double wcagGraphic = 3;

/// Luminance relative d'une couleur sRGB (l'alpha est ignoré : composer
/// d'abord avec [over]).
double luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Rapport de contraste entre deux couleurs OPAQUES.
double contrast(Color a, Color b) {
  final first = luminance(a);
  final second = luminance(b);
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

/// Une couleur écrite comme dans `tokens.json` (« #9943FC », l'alpha en
/// tête s'il n'est pas plein) : un manquement se lit sans convertir.
String hex(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${(argb.startsWith('ff') ? argb.substring(2) : argb).toUpperCase()}';
}

/// Une couleur translucide posée sur ce qu'elle recouvre : c'est la couleur
/// que l'œil reçoit, donc celle qu'on mesure.
Color over(Color top, Color below) => Color.alphaBlend(top, below);

/// Les couleurs d'un dégradé où un texte CLAIR est le moins lisible.
///
/// Interpolé canal par canal en sRGB, un dégradé a une luminance CONVEXE
/// entre deux arrêts (chaque canal linéarisé l'est) : elle ne dépasse jamais
/// le plus clair des deux. Contre un texte plus clair que le fond, les
/// arrêts encadrent donc toute la course — les mesurer suffit, où que le
/// libellé se pose et quelle que soit sa largeur.
List<Color> stopsOf(Gradient gradient) => gradient.colors;

/// Tout ce qui s'écrit ou se dessine sur [surface] — un `DecoratedBox` à
/// dégradé ou à aplat —, mesuré contre CHAQUE arrêt du dégradé : les textes
/// au seuil de 4,5:1, les icônes à 3:1. Rend les manquements, lisibles.
///
/// L'encre translucide se compose sur le fond avant la mesure, et les
/// aplats posés entre la surface et l'encre (une pastille, un voile) se
/// composent sur l'arrêt : c'est ce que l'œil reçoit. Une encre posée sur
/// une surface À ELLE — un sceau peint, un médaillon en dégradé — n'est pas
/// mesurée ici. La méthode vaut pour une encre CLAIRE (voir [stopsOf]).
List<String> inkFailuresOn(WidgetTester tester, Finder surface) {
  final surfaceElement = tester.element(surface);
  final decoration =
      (surfaceElement.widget as DecoratedBox).decoration as BoxDecoration;
  final base = decoration.gradient?.colors ?? [decoration.color!];
  final failures = <String>[];

  final glyphs = find.descendant(of: surface, matching: find.byType(RichText));
  for (final element in glyphs.evaluate()) {
    final span = (element.widget as RichText).text;
    final ink = span.style?.color;
    if (ink == null) continue;
    var isIcon = false;
    var nested = false;
    final veils = <Color>[];
    element.visitAncestorElements((ancestor) {
      if (ancestor == surfaceElement) return false;
      final widget = ancestor.widget;
      if (widget is Icon) isIcon = true;
      if (widget is CustomPaint &&
          (widget.painter != null || widget.foregroundPainter != null)) {
        nested = true;
      }
      if (widget is DecoratedBox &&
          widget.position == DecorationPosition.background) {
        final layer = widget.decoration;
        if (layer is! BoxDecoration ||
            layer.gradient != null ||
            layer.image != null) {
          nested = true;
        } else if (layer.color != null) {
          veils.add(layer.color!);
        }
      }
      return true;
    });
    // Posée sur une surface À ELLE (un sceau dessiné, un médaillon en
    // dégradé), l'encre se mesure contre celle-là, pas contre le bandeau.
    if (nested) continue;
    final threshold = isIcon ? wcagGraphic : wcagText;
    for (final stop in base) {
      var fill = stop;
      for (final veil in veils.reversed) {
        fill = over(veil, fill);
      }
      final ratio = contrast(over(ink, fill), fill);
      if (ratio < threshold) {
        final what = isIcon ? 'icône' : '« ${span.toPlainText()} »';
        failures.add(
          '$what : ${ratio.toStringAsFixed(2)}:1 sur ${hex(fill)} '
          '(seuil $threshold)',
        );
      }
    }
  }
  return failures;
}

/// La surface colorée qui porte un [gradient] donné.
Finder surfacePainting(Gradient gradient) => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).gradient == gradient,
);
