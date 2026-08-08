import 'package:flutter/material.dart';

/// Texte qui **choisit sa taille pour remplir la boîte qu'on lui donne**.
///
/// Utile quand la place est imposée et la longueur variable : la citation du
/// jour tient dans le même cadre qu'elle fasse 33 ou 66 caractères, en
/// grossissant quand elle est courte et en se resserrant quand elle est
/// longue. Sans cela, le cadre paraît creux un jour et déborde le lendemain.
///
/// **Exige une hauteur bornée** : sans plafond vertical, il n'y a rien à
/// remplir et la taille maximale est retenue.
///
/// La taille est trouvée par dichotomie sur [minFontSize] … [maxFontSize],
/// avec un vrai `TextPainter` — donc en tenant compte de la police réelle, du
/// crénage et des retours à la ligne. Contrairement à `FittedBox`, le texte
/// n'est jamais déformé ni mis à l'échelle : c'est la police qui change de
/// corps, la mise en page étant recalculée à chaque essai.
class AppFittedText extends StatefulWidget {
  const AppFittedText(
    this.text, {
    required this.style,
    required this.minFontSize,
    required this.maxFontSize,
    this.textAlign = TextAlign.start,
    super.key,
  }) : assert(
          minFontSize > 0 && minFontSize <= maxFontSize,
          'Bornes de taille incohérentes',
        );

  final String text;

  /// Style de référence ; seule sa `fontSize` est remplacée.
  final TextStyle style;
  final double minFontSize;
  final double maxFontSize;
  final TextAlign textAlign;

  @override
  State<AppFittedText> createState() => _AppFittedTextState();
}

class _AppFittedTextState extends State<AppFittedText> {
  /// Précision de la dichotomie, en points. Un quart de point est invisible
  /// à l'œil et borne la recherche à ~7 itérations.
  static const double _precision = 0.25;

  @override
  void initState() {
    super.initState();
    // Les polices embarquées se chargent APRÈS les premières images. Mesurer
    // une seule fois donnerait une taille calculée sur la police de repli,
    // bien plus étroite : le texte choisi trop grand déborderait ensuite.
    // C'est exactement ce que fait le rendu de texte de Flutter en interne.
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    super.dispose();
  }

  void _onFontsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final fontSize = _bestFontSize(constraints, scaler);
        final maxLines = _maxLines(constraints, fontSize, scaler);
        return Text(
          widget.text,
          textAlign: widget.textAlign,
          maxLines: maxLines,
          // L'abrègement n'a de sens QU'AVEC un nombre de lignes : demandé
          // sans lui, le moteur tronque dès la première ligne — le texte
          // ajusté n'aurait alors jamais l'occasion de remplir sa boîte.
          overflow:
              maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
          style: widget.style.copyWith(fontSize: fontSize),
        );
      },
    );
  }

  double _bestFontSize(BoxConstraints constraints, TextScaler scaler) {
    if (!constraints.hasBoundedHeight || widget.text.isEmpty) {
      return widget.maxFontSize;
    }
    if (_fits(widget.maxFontSize, constraints, scaler)) {
      return widget.maxFontSize;
    }

    // Invariant : `low` tient toujours, `high` ne tient jamais.
    var low = widget.minFontSize;
    var high = widget.maxFontSize;
    while (high - low > _precision) {
      final middle = (low + high) / 2;
      if (_fits(middle, constraints, scaler)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  bool _fits(double fontSize, BoxConstraints constraints, TextScaler scaler) {
    return _paint(fontSize, constraints, scaler).height <=
        constraints.maxHeight;
  }

  /// Filet de sécurité : si même [AppFittedText.minFontSize] ne tient pas
  /// (boîte minuscule, police système très agrandie), le texte s'abrège au
  /// lieu de déborder.
  int? _maxLines(
    BoxConstraints constraints,
    double fontSize,
    TextScaler scaler,
  ) {
    if (!constraints.hasBoundedHeight) {
      return null;
    }
    final painter = _paint(fontSize, constraints, scaler);
    if (painter.height <= constraints.maxHeight) {
      return null; // tout tient : aucune limite à poser
    }
    final lineHeight = painter.preferredLineHeight;
    return lineHeight <= 0
        ? 1
        : (constraints.maxHeight / lineHeight).floor().clamp(1, 1 << 20);
  }

  TextPainter _paint(
    double fontSize,
    BoxConstraints constraints,
    TextScaler scaler,
  ) {
    return TextPainter(
      text: TextSpan(
        text: widget.text,
        style: widget.style.copyWith(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      textAlign: widget.textAlign,
      textScaler: scaler,
    )..layout(maxWidth: constraints.maxWidth);
  }
}
