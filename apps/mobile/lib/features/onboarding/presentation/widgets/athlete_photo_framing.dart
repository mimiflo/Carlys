import 'dart:math' as math;
import 'dart:ui' show Size;

/// Cadrage de la photographie de la page de marque : les seuls chiffres qui
/// commandent la taille et la position de la personne à l'écran.
///
/// Sortis du widget pour être vérifiables sur toutes les tailles d'écran —
/// c'est l'endroit du design qui se dérègle le plus vite, et le seul dont la
/// spécification donne une exigence plutôt qu'une valeur.
abstract final class AthletePhotoFraming {
  /// Dimensions du fichier, et position du LOGO DORSAL dedans (mesurées).
  static const Size source = Size(1024, 1536);
  static const double markLeft = 565;
  static const double markRight = 636;

  // ── Trois valeurs relevées sur la planche validée ──────────────────
  //
  // Elles sont exprimées en fractions d'ÉCRAN, pas de cadre : c'est ce qu'on
  // voit, et c'est la seule forme qui se transpose d'un format à l'autre. La
  // spécification, elle, donne des valeurs de cadre (`width: 62%`,
  // `object-position: 22%`) relevées sur une planche au rapport 0,59 ; un
  // téléphone fait 0,46, et les mêmes chiffres y donnent un tout autre cadrage.

  /// Part du cliché montrée en largeur.
  static const double shownWidth = 0.55;

  /// Position du logo dorsal, en fraction de la largeur d'écran.
  ///
  /// La planche le pose à 0,928 ; on le décale un peu à droite, la personne
  /// suivant. Le décalage est borné par lui : au-delà, il sort du cadre, et la
  /// spécification exige qu'il reste visible.
  static const double markScreenX = 0.945;

  /// Descente de la photographie, en fraction de la hauteur d'écran.
  ///
  /// La planche n'en a pas besoin : son format laisse peu de vide, la personne
  /// et le bloc de texte y commencent ensemble. Sur un téléphone, plus haut, le
  /// texte descend d'un quart du vide disponible — et la personne doit suivre,
  /// sans quoi elle reste accrochée au bord haut pendant que les mots
  /// descendent. Ce qui sort en bas est de toute façon couvert par les
  /// vignettes.
  /// Descente de la photographie, en fraction de la hauteur d'écran.
  static const double dropFactor = 0.04;

  /// Bornes du fondu du BAS, en fractions de la hauteur du cadre.
  ///
  /// Absentes de la planche, et pour cause : la photographie y occupe toute la
  /// hauteur, elle n'a pas de bord bas. Ici le cadre s'arrête au-dessus du
  /// pied de page, et sans extinction on voyait la coupe nette des jambes.
  ///
  /// Le fondu s'éteint AVANT le bord du cadre, pas dessus : terminé à 1.0, il
  /// restait quelques pour cent d'opacité juste avant la coupe — assez, sur du
  /// quasi-noir, pour qu'un liseré horizontal se lise encore. Les derniers
  /// 12 % du cadre sont donc entièrement transparents.
  static const List<double> bottomFade = [0.50, 0.88];

  /// Bornes du fondu du bord gauche, en fractions de la largeur d'écran :
  /// transparent avant la première, opaque après la seconde.
  ///
  /// Ce sont celles de la planche. Les avoir décalées vers la droite, pour
  /// que la personne ne passe pas derrière le texte, la faisait disparaître
  /// aux DEUX TIERS : elle n'était plus un grand élément de fond mais une
  /// vignette confinée à droite. C'est la PLAQUE SOMBRE (couche 7) et le voile
  /// horizontal (couche 4) qui rendent le texte lisible, pas l'effacement de
  /// la photographie.
  ///
  /// ÉCART ASSUMÉ : la planche les met à 0,38 et 0,566. Sur un écran étroit,
  /// la même tranche de cliché occupe 29 % de largeur en plus, et l'avant-bras
  /// venait toucher la fin des lignes. Le fondu est donc décalé, juste assez
  /// pour que le bras s'efface là où le texte s'écrit, pas au point de faire
  /// disparaître la personne, qui reste pleinement présente dès [fadeTo].
  ///
  /// [fadeFrom] est la SEULE garantie que l'écriture ne se pose pas sur le
  /// bras : la photographie y est encore entièrement transparente, donc la
  /// silhouette ne peut rien montrer avant. Mesurées sur les vraies fontes à
  /// 393 pt de large, les lignes les plus longues s'arrêtent à 0,521 (« Ton
  /// parcours est TON histoire. ») et 0,509 (« TON PARCOURS. ») ; le bord de
  /// l'avant-bras tombait, lui, à 0,545. Douze points d'écart, que la lueur
  /// du cliché comblait à l'œil : les mots s'écrivaient sur le bras. Porté à
  /// 0,58, le fondu tient la personne à une vingtaine de points des mots,
  /// sans la reléguer à droite. [clearance] mesure cette marge et
  /// `welcome_text_clearance_test.dart` échoue si une retouche la referme.
  static const double fadeFrom = 0.58;
  static const double fadeTo = 0.74;

  /// Marge, en fraction de largeur d'écran, entre la fin de la ligne la plus
  /// longue et le premier pixel possible de la photographie.
  ///
  /// Négative, l'écriture se pose sur la personne.
  static double clearance(double longestLineRight) =>
      fadeFrom - longestLineRight;

  /// Part de la hauteur d'écran occupée par le cadre.
  ///
  /// C'est le seul réglage de TAILLE : `cover` se règle sur la hauteur du
  /// cadre, tout le reste en découle. Moins que 1 rapetitit la personne sans
  /// rien changer à la part du cliché montrée. Le bas manquant tombe sous le
  /// bouton, là où le voile de pied de page est déjà opaque.
  static const double heightFactor = 0.80;

  /// Cadre de la photographie, ancré à droite.
  ///
  /// La largeur n'est pas la constante de la spécification mais se DÉDUIT de
  /// [shownWidth] : `cover` se règle sur la hauteur (le cliché est plus large,
  /// proportion gardée, que le cadre), donc c'est la largeur du cadre qui
  /// décide de la part du cliché visible. Fixée à 62 %, elle n'en montrait que
  /// 43 % sur un téléphone contre 55 % sur la planche — d'où le gros plan, la
  /// silhouette perdue et le logo dorsal hors champ.
  static Size boxFor(Size screen) {
    final height = heightFactor * screen.height;
    final width = math.min(
      screen.width,
      shownWidth * source.width * height / source.height,
    );
    return Size(width, height);
  }

  /// Cadrage horizontal qui pose le logo dorsal à [markScreenX] de l'écran.
  ///
  /// `cover` agrandit le cliché jusqu'à couvrir le cadre, puis en rogne le
  /// surplus ; `Alignment.x` choisit quelle part de ce surplus part à gauche.
  /// On ne fait qu'inverser la relation.
  static double alignmentFor(Size screen) {
    final box = boxFor(screen);
    final window = _windowWidth(box);
    final slack = source.width - window;
    if (slack <= 0) return 0;
    final boxLeft = 1 - box.width / screen.width;
    final placement = (markScreenX - boxLeft) / (box.width / screen.width);
    final left = (markLeft + markRight) / 2 - placement * window;
    return (2 * left / slack - 1).clamp(-1.0, 1.0);
  }

  /// Bornes du fondu, ramenées du repère de l'écran à celui du cadre.
  static List<double> fadeStopsFor(Size screen) {
    final box = boxFor(screen);
    final boxLeft = 1 - box.width / screen.width;
    final span = box.width / screen.width;
    return [
      ((fadeFrom - boxLeft) / span).clamp(0.0, 1.0),
      ((fadeTo - boxLeft) / span).clamp(0.0, 1.0),
    ];
  }

  /// Fenêtre du cliché réellement visible, en pixels du fichier.
  static (double, double) windowFor(Size screen) {
    final box = boxFor(screen);
    final window = _windowWidth(box);
    final left = (1 + alignmentFor(screen)) / 2 * (source.width - window);
    return (left, left + window);
  }

  static double _windowWidth(Size box) {
    final scale = math.max(
      box.width / source.width,
      box.height / source.height,
    );
    return box.width / scale;
  }
}
