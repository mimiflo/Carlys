/// LE TEXTE AGRANDI, MESURÉ.
///
/// Les défauts de mise en page que l'audit de septembre 2026 a relevés
/// (texte ×1,15 à ×2, écrans de 320 à 390 points) se mesuraient avec les
/// VRAIES polices. La police de test dessine des blocs d'un cadratin, près
/// de deux fois plus larges qu'Inter : elle ferait tomber des mises en page
/// justes, et déplacerait les coupures. Ce fichier fournit donc trois
/// choses : les polices de l'application, un écran à la largeur et au
/// facteur de texte voulus, et deux détecteurs — le mot coupé en son milieu
/// (« Communaut / é »), le texte tronqué.
///
/// Un débordement, lui, n'a pas besoin de détecteur : le harnais le reçoit
/// comme une exception et fait échouer l'épreuve de lui-même.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Charge les polices du bundle (Inter, la mono…) et, quand le SDK les a en
/// cache, Roboto à la place de la police de test pour les styles sans
/// famille. La galerie de captures s'en sert aussi (`loadRealFonts`) : les
/// épreuves mesurent avec les polices qu'elle dessine. À appeler dans un
/// `setUpAll`.
Future<void> loadAppFonts() async {
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (data) async => json.decode(data) as List<dynamic>,
  );
  for (final entry in manifest.whereType<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    // LIMITE CONNUE : `FontLoader` n'expose aucun poids, et le harnais ne sait
    // donc pas choisir la graisse — c'est la PREMIÈRE fonte chargée qui sert à
    // tous les poids, les autres étant simulées. Les captures sous-rendent donc
    // le gras : mesuré, « TON PARCOURS. » en 24/w700 fait 192 px ici contre
    // ~211 sur un vrai appareil. On charge le 400 en tête, le plus proche de la
    // moyenne de l'interface — sans quoi une fonte fine déclarée en premier
    // amaigrirait toute la galerie.
    final fonts =
        (entry['fonts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList()
          ..sort((a, b) {
            int gap(Map<String, dynamic> f) =>
                ((f['weight'] as int?) ?? 400) - 400;
            return gap(a).abs().compareTo(gap(b).abs());
          });
    for (final font in fonts) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }

  // Roboto depuis le cache du SDK : la police de test « blocs » fausse les
  // largeurs. « FlutterTest » est la police par défaut du harnais : la
  // remplacer aussi rend lisibles les styles sans famille explicite.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final fontsDir = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
  if (!fontsDir.existsSync()) return;
  for (final family in const ['Roboto', 'FlutterTest']) {
    final loader = FontLoader(family);
    for (final file in fontsDir.listSync().whereType<File>()) {
      if (file.path.endsWith('.ttf') && file.path.contains('Roboto-')) {
        loader.addFont(
          file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
    }
    await loader.load();
  }
}

/// Un téléphone de [width] points de large, texte système × [textScale].
void setPhone(
  WidgetTester tester, {
  required double width,
  double height = 844,
  double textScale = 1,
}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

final _letter = RegExp('[A-Za-zÀ-ÖØ-öø-ÿŒœ0-9]');

Iterable<RenderParagraph> _paragraphs(Finder within) sync* {
  final texts = find.descendant(
    of: within,
    matching: find.byType(RichText),
    matchRoot: true,
  );
  for (final element in texts.evaluate()) {
    final render = element.renderObject;
    if (render is RenderParagraph && render.attached && render.hasSize) {
      yield render;
    }
  }
}

/// Les textes de [within] qu'un retour à la ligne coupe AU MILIEU d'un mot,
/// sous la forme « Communaut|é » — la coupure que le lecteur ne recolle pas.
/// Vide quand chaque ligne se termine entre deux mots.
List<String> midWordBreaks(Finder within) {
  final found = <String>[];
  for (final render in _paragraphs(within)) {
    final plain = render.text.toPlainText();
    if (plain.length < 2 || render.size.width <= 0) continue;
    final painter = TextPainter(
      text: render.text,
      textDirection: render.textDirection,
      textAlign: render.textAlign,
      textScaler: render.textScaler,
      maxLines: render.maxLines,
      strutStyle: render.strutStyle,
      textWidthBasis: render.textWidthBasis,
      textHeightBehavior: render.textHeightBehavior,
      locale: render.locale,
    )..layout(maxWidth: render.size.width);
    var start = 0;
    while (start < plain.length) {
      final end = painter.getLineBoundary(TextPosition(offset: start)).end;
      // Le blanc ou le saut de ligne qui clôt une ligne appartient à cette
      // ligne : sa position rend la même borne. On passe au caractère
      // suivant plutôt que de s'arrêter — sans quoi tout ce qui suit la
      // première ligne échappait au détecteur.
      if (end <= start) {
        start++;
        continue;
      }
      if (end < plain.length &&
          _letter.hasMatch(plain[end - 1]) &&
          _letter.hasMatch(plain[end])) {
        found.add(
          '${plain.substring(0, end)}|${plain.substring(end)} '
          '(largeur ${render.size.width.toStringAsFixed(1)})',
        );
      }
      start = end;
    }
    painter.dispose();
  }
  return found;
}

/// Les textes de [within] que leur `maxLines` a tronqués (ellipse ou coupe).
List<String> truncatedTexts(Finder within) => [
  for (final render in _paragraphs(within))
    if (render.didExceedMaxLines) render.text.toPlainText(),
];
