import 'package:flutter/material.dart';

import '../typography/app_typography.dart';

/// Un texte dont AUCUN MOT ne se coupe.
///
/// Il passe à la ligne entre deux mots, comme n'importe quel texte. Mais
/// quand un mot SEUL est plus large que sa boîte — texte système agrandi,
/// écran étroit, colonne serrée —, le moteur le coupait en son milieu :
/// « Communaut / é », « uniquemen / t ». Une coupure dans un mot ne se
/// recolle pas à la lecture ; ici, le corps descend juste assez pour que le
/// plus long mot tienne, et rien d'autre ne change. À la taille d'origine,
/// sur une largeur ordinaire, ce widget est un `Text`.
///
/// Distinct d'[AppFittedText], qui REMPLIT une hauteur imposée : celui-ci
/// ne cherche que la largeur de son plus long mot, et garde la hauteur que
/// son texte demande.
class AppWholeWordsText extends StatelessWidget {
  const AppWholeWordsText(
    this.text, {
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Essais de réduction au plus : la largeur d'un mot n'est pas tout à fait
  /// proportionnelle au corps (crénage, mise à l'échelle non linéaire du
  /// texte système), d'où une vérification après chaque réduction.
  static const int _attempts = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitted = constraints.hasBoundedWidth
            ? fittedStyle(
                context,
                texts: [text],
                style: style,
                maxWidth: constraints.maxWidth,
              )
            : style;
        return Text(
          text,
          style: fitted,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }

  /// Le style qui laisse le plus long mot de [texts] tenir dans [maxWidth] :
  /// [style] lui-même quand tout tient déjà.
  ///
  /// Public pour les textes posés sous un `IntrinsicHeight`, où ce widget —
  /// qui demande sa largeur par un `LayoutBuilder` — ne peut pas vivre : le
  /// parent mesure sa colonne et passe le style. Plusieurs textes donnent UN
  /// corps commun, pour que des libellés voisins gardent la même taille.
  static TextStyle fittedStyle(
    BuildContext context, {
    required Iterable<String> texts,
    required TextStyle style,
    required double maxWidth,
  }) {
    var base = DefaultTextStyle.of(context).style.merge(style);
    // Mesurer ce que `Text` DESSINE : sous le réglage système « texte en
    // gras », il passe toute graisse à bold, et un mot qui tenait en graisse
    // normale se coupait une fois grossi.
    if (MediaQuery.boldTextOf(context)) {
      base = base.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final origin = base.fontSize;
    if (origin == null || maxWidth <= 0) return style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final words = [
      // Les seuls blancs où la ligne peut se couper : l'espace insécable de
      // « 24 % » lie ses deux moitiés en un seul mot, comme le fait le
      // moteur.
      for (final text in texts) ...text.split(RegExp('[ \t\n]+')),
    ].where((word) => word.isNotEmpty);

    var size = origin;
    var widest = _widestWord(words, base, scaler, direction);
    for (var i = 0; i < _attempts && widest > maxWidth; i++) {
      size *= maxWidth / widest * 0.995;
      widest = _widestWord(
        words,
        AppTypography.resized(base, size),
        scaler,
        direction,
      );
    }
    return size == origin ? style : AppTypography.resized(base, size);
  }

  static double _widestWord(
    Iterable<String> words,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    var widest = 0.0;
    for (final word in words) {
      final width = AppTypography.lineWidth(
        word,
        style,
        scaler: scaler,
        direction: direction,
      );
      if (width > widest) widest = width;
    }
    return widest;
  }
}
