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
  /// Nombre de MISES EN PAGE effectuées depuis le démarrage.
  ///
  /// Uniquement pour les tests : la mémoïsation n'a aucun effet observable à
  /// l'écran — c'est bien le but — et un test qui ne peut pas la voir ne
  /// garderait rien. Ce compteur la rend mesurable.
  @visibleForTesting
  static int misesEnPage = 0;

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

  @override
  void didUpdateWidget(AppFittedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.minFontSize != widget.minFontSize ||
        oldWidget.maxFontSize != widget.maxFontSize) {
      _dernier = null;
    }
  }

  void _onFontsChanged() {
    if (mounted) {
      // Les polices ont changé : toute mise en page mémorisée est caduque.
      _dernier = null;
      setState(() {});
    }
  }

  /// La dernière mise en page calculée, et les entrées qui l'ont produite.
  ///
  /// La dichotomie tourne dans le `builder` d'un `LayoutBuilder` : elle se
  /// rejouait donc à CHAQUE reconstruction, soit huit mises en page de texte
  /// par tuile de l'accueil, pour un résultat inchangé neuf fois sur dix —
  /// le texte, le style et la boîte sont les mêmes d'une image à l'autre.
  /// Une mémoire d'UN élément suffit : ce qui change d'une reconstruction à
  /// l'autre, ce sont les données affichées, pas la géométrie.
  _Ajustement? _dernier;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final ajustement = _ajustement(constraints, scaler);
        final fontSize = ajustement.fontSize;
        final maxLines = ajustement.maxLines;
        return Text(
          widget.text,
          textAlign: widget.textAlign,
          maxLines: maxLines,
          // L'abrègement n'a de sens QU'AVEC un nombre de lignes : demandé
          // sans lui, le moteur tronque dès la première ligne — le texte
          // ajusté n'aurait alors jamais l'occasion de remplir sa boîte.
          overflow: maxLines == null
              ? TextOverflow.clip
              : TextOverflow.ellipsis,
          style: widget.style.copyWith(fontSize: fontSize),
        );
      },
    );
  }

  /// Le corps et le nombre de lignes, calculés une fois par géométrie.
  _Ajustement _ajustement(BoxConstraints constraints, TextScaler scaler) {
    final precedent = _dernier;
    if (precedent != null &&
        precedent.text == widget.text &&
        precedent.style == widget.style &&
        precedent.constraints == constraints &&
        precedent.scaler == scaler) {
      return precedent;
    }
    final fontSize = _bestFontSize(constraints, scaler);
    final calcul = _Ajustement(
      text: widget.text,
      style: widget.style,
      constraints: constraints,
      scaler: scaler,
      fontSize: fontSize,
      maxLines: _maxLines(constraints, fontSize, scaler),
    );
    _dernier = calcul;
    return calcul;
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
    // Le peintre est LIBÉRÉ : il tient des ressources natives, et la
    // dichotomie en construit une dizaine par appel. Les abandonner au
    // ramasse-miettes marche, mais retarde la libération d'autant.
    final painter = _paint(fontSize, constraints, scaler);
    final tient = painter.height <= constraints.maxHeight;
    painter.dispose();
    return tient;
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
    final hauteur = painter.height;
    final lineHeight = painter.preferredLineHeight;
    painter.dispose();
    if (hauteur <= constraints.maxHeight) {
      return null; // tout tient : aucune limite à poser
    }
    return lineHeight <= 0
        ? 1
        : (constraints.maxHeight / lineHeight).floor().clamp(1, 1 << 20);
  }

  TextPainter _paint(
    double fontSize,
    BoxConstraints constraints,
    TextScaler scaler,
  ) {
    AppFittedText.misesEnPage += 1;
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

/// Une mise en page ajustée, et les entrées dont elle découle.
///
/// Les quatre entrées suffisent : le corps retenu ne dépend que du texte, de
/// son style, de la boîte disponible et de l'échelle système.
class _Ajustement {
  const _Ajustement({
    required this.text,
    required this.style,
    required this.constraints,
    required this.scaler,
    required this.fontSize,
    required this.maxLines,
  });

  final String text;
  final TextStyle style;
  final BoxConstraints constraints;
  final TextScaler scaler;
  final double fontSize;
  final int? maxLines;
}
