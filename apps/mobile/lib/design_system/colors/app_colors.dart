import 'package:flutter/material.dart';

/// Palette Carlys — refonte « premium dark-first ».
///
/// Source de vérité : packages/design-tokens/src/tokens.json.
/// Toute nouvelle couleur doit être ajoutée aux tokens PUIS reflétée ici —
/// jamais codée en dur dans un écran.
///
/// Règles d'usage (handoff/README.md) :
///  - l'accent orange ne sert qu'à UNE action ou métrique clé par écran ;
///  - le violet porte l'atmosphère (halos, gradients, scènes 3D), pas les
///    boutons ;
///  - le magenta vit dans les dégradés et sur les COURBES DE DONNÉES des
///    graphiques (choix produit d'août 2026 : la donnée doit trancher sur le
///    décor violet/orange) — jamais sur les surfaces ni le texte ;
///  - aucune ombre portée sur les cartes.
///
/// **UN JETON INUTILISÉ N'EST PAS FORCÉMENT MORT**, et la distinction se
/// tranche en une question : est-il dans `tokens.json` ? S'il y est, il
/// REFLÈTE la source de vérité — c'est une palette, et une palette se tient
/// entière. La rampe neutre (0 → 950) en est l'exemple : quatre de ses
/// échelons ne sont appelés nulle part, et les retirer casserait le miroir
/// pour ne gagner que quatre lignes.
///
/// S'il n'y est pas, en revanche, il a été inventé ici : inutilisé, il est
/// bien mort. Quatre l'étaient et sont partis en septembre 2026
/// (`violetRampUp`, `ringHole`, `primaryFill`, `vignetteBorder`) — chacun
/// décrivait un usage précis qu'un remaniement avait emporté sans lui. Une
/// couleur qu'on veut garder se promeut dans `tokens.json`, où elle
/// redevient une décision de design plutôt qu'un vestige.
abstract final class AppColors {
  // Marque — violet électrique
  static const Color primary = Color(0xFF9B30FF);
  static const Color primaryDark = Color(0xFF7B1FFF);
  static const Color primaryLight = Color(0xFFC88BFF);

  /// Extrémité claire du dégradé violet. Surfaces sans texte uniquement
  /// (blanc dessus : 3.86, sous le seuil AA).
  static const Color primaryFlash = Color(0xFFB44DFF);

  /// Accent unique de l'application : chaud, lisible sur le fond sombre
  /// (7.82) comme sous du texte noir (8.12).
  static const Color accent = Color(0xFFFF7A45);
  static const Color accentDark = Color(0xFFE85F2A);

  /// Charnière entre le violet et l'orange. **Jamais utilisée à plat** — voir
  /// la règle d'usage en tête de classe.
  static const Color magenta = Color(0xFFED35A9);

  /// Rose des CŒURS, et d'eux seuls.
  ///
  /// Un cœur reçu n'est pas une action à faire : il sort donc de l'accent
  /// orange, qui reste la couleur des gestes (ajouter un ami, encourager)
  /// comme partout ailleurs dans l'application. Réservé à l'icône du cœur,
  /// jamais aux surfaces, au texte ni aux autres motifs de la communauté.
  static const Color affection = Color(0xFFFF5C9D);

  /// Dégradé d'ambiance : ce qui remplit (jauges, halos) plutôt que ce qui
  /// se lit. Il s'éclaircit dans le sens de la progression.
  static const LinearGradient violetRamp = LinearGradient(
    colors: [primaryDark, primaryFlash],
  );

  /// Dégradé d'énergie, du violet à l'orange en passant par le magenta.
  /// Rare par construction : un seul point d'écran, sinon il perd son éclat.
  static const LinearGradient energy = LinearGradient(
    colors: [primary, magenta, accent],
  );

  // ── Dégradé de MARQUE ────────────────────────────────────────────
  //
  // Relevé sur le logo Carlys. Réservé aux surfaces de marque (page de
  // bienvenue, logo) : il ne remplace jamais `primary`/`accent`, qui restent
  // les couleurs de l'application. Les mélanger diluerait les deux.
  static const Color signatureStart = primaryDark;
  static const Color signatureMid = Color(0xFFC42EE0);
  static const Color signatureEnd = Color(0xFFFF7A45);

  /// Dégradé de marque, de gauche à droite.
  ///
  /// Les arrêts sont explicites : à parts égales, le magenta central occupe
  /// la moitié de la course et l'orange n'apparaît que dans les tout derniers
  /// pixels — mesuré sur le bouton de bienvenue, il n'y arrivait jamais. Le
  /// violet tient la première moitié, l'orange le dernier dixième en aplat.
  static const LinearGradient signature = LinearGradient(
    colors: [signatureStart, signatureMid, signatureEnd],
    stops: [0, 0.45, 0.9],
  );

  // Bouton des écrans d'ENTRÉE (tokens.json → color.brand.cta*) : violet
  // clair vers violet profond, sans l'orange de la signature. Relevé au
  // pixel sur la maquette de septembre 2026. Réservé à ces boutons.
  static const Color ctaStart = Color(0xFFA355FC);
  static const Color ctaEnd = Color(0xFF7029D2);

  /// Dégradé du bouton d'entrée, de gauche à droite.
  static const LinearGradient cta = LinearGradient(colors: [ctaStart, ctaEnd]);

  /// Icônes de préfixe des champs des écrans d'entrée (tokens.json →
  /// color.brand.fieldIcon) : rose clair demandé par le produit — distinct
  /// d'[affection], le rose des cœurs, qui reste réservé aux encouragements.
  static const Color fieldIcon = Color(0xFFFF9ECF);

  // Neutres
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFAFB);
  static const Color neutral100 = Color(0xFFF4F4F6);
  static const Color neutral200 = Color(0xFFE4E4EA);
  static const Color neutral300 = Color(0xFFD1D1DA);
  static const Color neutral400 = Color(0xFFA5A5B5);
  static const Color neutral500 = Color(0xFF7A7A8C);
  static const Color neutral600 = Color(0xFF55556A);
  static const Color neutral700 = Color(0xFF3B3B4F);
  static const Color neutral800 = Color(0xFF26263A);
  static const Color neutral900 = Color(0xFF16162A);
  static const Color neutral950 = Color(0xFF0B0B18);

  // Sémantiques
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// Le rouge d'un REMPLISSAGE sous un libellé blanc : le bouton d'un geste
  /// destructif (`AppButtonVariant.destructive`), dans chaque popup qui
  /// supprime, retire ou quitte.
  ///
  /// Blanc sur [danger] ne tient que 3,76:1, sous le seuil AA (4,5) d'un
  /// libellé de 15 points ; ce rouge plus profond en tient 4,83. [danger]
  /// reste le rouge des textes et des icônes d'erreur, qui se posent sur les
  /// surfaces sombres et y ont besoin de sa clarté.
  static const Color dangerStrong = Color(0xFFDC2626);

  /// Un rôle, une couleur — `logout` a été SUPPRIMÉ.
  ///
  /// Ce `#FF6B6B` ne figurait dans aucun jeton (`semantic` n'en compte que
  /// quatre), et peignait pourtant le même booléen `destructive` que
  /// `danger` : `app_settings_group.dart` employait l'un,
  /// `community_overflow_menu.dart` l'autre, pour la même intention. Deux
  /// rouges pour un rôle, ce n'est pas une nuance, c'est une divergence — et
  /// l'admin, lui, sert déjà `semantic.danger` à ses actions destructives.
  /// Les trois usages restants sont passés à `danger`.

  // Surfaces — thème sombre de RÉFÉRENCE (dark-first)
  //
  // Teintées de violet plutôt que neutres : un fond gris sous un violet
  // électrique le fait paraître sale ; le même violet sur un fond qui en
  // porte la trace ressort.
  static const Color darkBackground = Color(0xFF08050E);
  static const Color darkSurface = Color(0xFF15101F);
  static const Color darkSurfaceAlt = Color(0xFF1C1529);

  /// Cartes posées sur une scène 3D uniquement (avec BackdropFilter blur 24).
  static const Color darkGlass = Color(0xB815101F);

  /// Voile derrière une popup (tokens.json → color.surface.darkScrim) : le
  /// fond de l'application à 72 %. Il éteint l'écran sans le noircir, et la
  /// carte centrée devient la seule chose qu'on lise.
  static const Color darkScrim = Color(0xB808050E); // fond .72

  /// Voile LÉGER derrière un simple message passager (tokens.json →
  /// color.surface.darkScrimSoft) : le fond de l'application à 40 %.
  /// Purement visuel, il laisse passer le toucher ; il détache la carte des
  /// cartes de l'écran sans l'éteindre.
  static const Color darkScrimSoft = Color(0x6608050E); // fond .40

  // Rôles de texte et traits du thème sombre
  //
  // Les gris se MESURENT, pas seulement à l'œil, et deux fois : chaque rôle
  // de texte tient AA (4,5:1) et l'icône tient le seuil graphique (3:1) sur
  // la plus claire des surfaces sombres, `surfaceIcon`, parce que les
  // libellés se posent aussi sur les plaques gravées ; et deux gris voisins
  // gardent un écart PERCEPTIBLE (luminance relative >= 1,2:1), sans quoi la
  // hiérarchie n'existe que dans le code. Entre le gris minimal AA sur
  // `surfaceIcon` et le secondaire, il n'y a la place que d'UN pas : un seul
  // gris en retrait, donc, et non deux nuances indiscernables. Le test
  // `app_colors_test.dart` vérifie les deux règles.
  static const Color darkTextPrimary = Color(0xFFF2F2F6);
  static const Color darkTextSecondary = Color(0xFF9A9AAE);
  static const Color darkTextTertiary = Color(0xFF8A8A9E);
  static const Color darkIconInactive = Color(0xFF6D6D81);
  static const Color darkBorder = Color(0x12FFFFFF);
  static const Color darkBorderStrong = Color(0x24FFFFFF);

  // Surfaces — thème clair (secondaire) et OLED
  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF4F4F6);
  static const Color oledBackground = Color(0xFF000000);

  // Teintes dérivées récurrentes (handoff/design-tokens.md)
  static const Color primaryHalo = Color(0x4D9B30FF); // primary .30
  static const Color primaryCardStrong = Color(0x479B30FF); // primary .28
  static const Color primaryCardSoft = Color(0x0D9B30FF); // primary .05

  /// Violet transparent : extrémité d'un halo violet qui s'éteint. Un
  /// dégradé vers du NOIR transparent traverse un violet assombri et
  /// désaturé avant de disparaître (l'interpolation se fait canal par canal,
  /// alpha compris) ; vers le même violet à alpha zéro, il garde sa teinte
  /// jusqu'au bout.
  static const Color primaryCardClear = Color(0x009B30FF); // primary .00

  /// Voile sous la courbe rose des graphiques (magenta .05).
  static const Color magentaCardSoft = Color(0x0DED35A9);
  static const Color accentBadgeBg = Color(0x1FFF7A45); // accent .12
  static const Color accentBadgeBorder = Color(0x47FF7A45); // accent .28
  static const Color primaryBadgeBg = Color(0x1F9B30FF); // primary .12
  static const Color primaryBadgeBorder = Color(0x479B30FF); // primary .28
  static const Color successBadgeBg = Color(0x1F22C55E); // success .12
  static const Color successBadgeBorder = Color(0x4722C55E); // success .28
  static const Color neutralBadgeBg = Color(0x12FFFFFF); // blanc .07
  static const Color neutralBadgeText = Color(0xFFD3D3E4);
  static const Color gaugeTrack = Color(0x12FFFFFF); // blanc .07
  static const Color primaryLightBorder = Color(0x4DC88BFF); // primaryLight .30
  static const Color difficultyTrack = Color(0x1FFFFFFF); // blanc .12
  static const Color rowDivider = Color(0x0FFFFFFF); // blanc .06
  static const Color heatEmpty = Color(0x0DFFFFFF); // blanc .05
  static const Color heatOutOfMonth = Color(0x08FFFFFF); // blanc .03

  // Voiles, halos et bokeh du décor de la page de bienvenue — posés SUR la
  // photographie. Nommés ICI plutôt qu'écrits dans l'écran : ils dérivent
  // tous d'un jeton, et doivent suivre la palette si elle change. Le
  // précédent est documenté : les scènes 3D codaient leur vert en dur, et
  // l'hélice serait restée verte après le changement de palette.
  static const Color backdropClear = Color(0x0008050E); // fond .00
  static const Color backdropVeil = Color(0xC708050E); // fond .78
  static const Color backdropVeilStrong = Color(0xCC08050E); // fond .80
  static const Color backdropVeilSoft = Color(0x6B08050E); // fond .42

  /// Cœur de la plaque sombre qui rend le texte lisible : un noir franc, et
  /// non le fond violacé, pour ne pas teinter la personne photographiée.
  static const Color backdropPlate = Color(0xEB000000); // noir .92
  static const Color backdropPlateEdge = Color(0xC7030308); // noir violacé .78
  static const Color backdropHaloMagenta = Color(0x33C42EE0); // signature .20
  static const Color backdropHaloIndigo = Color(0x1F7B1FFF); // primaryDark .12
  static const Color backdropGlow = Color(0x339B30FF); // primary .20
  static const Color backdropGlowSoft = Color(0x129B30FF); // primary .07
  static const Color backdropBokehAccent = Color(0x47FF7A45); // accent .28
  static const Color backdropBokehMagenta = Color(0x3DC42EE0); // signature .24
  static const Color backdropBokehIndigo = Color(0x337B1FFF); // primaryDark .20

  /// Blanc transparent : extrémité des masques de dégradé (le masque ne
  /// colore rien, il ouvre et ferme l'opacité).
  static const Color neutral0Clear = Color(0x00FFFFFF); // blanc .00

  /// Encre de l'ombre portée du bloc de signature : le MÊME fond que les
  /// voiles ci-dessus, à deux densités. Elle décolle le mot et la devise du
  /// cliché quand la page de marque est vue en plein soleil.
  static const Color brandInkShadow = Color(0xD908050E); // fond .85
  static const Color brandInkShadowTight = Color(0x9908050E); // fond .60

  /// Lueur du sceau de marque, dérivée du dégradé de signature.
  static const Color brandMarkGlow = Color(0x59C42EE0); // signature .35

  // ── Profil de progression (refonte, handoff d'août 2026) ───────────────
  //
  // L'écran est un ATELIER, pas un jeu. Sa matière est la fabrication :
  // surfaces gravées, filets, cachets. Ces teintes n'existent que là, et
  // elles dérivent toutes de la palette de marque.

  /// Haut du dégradé d'une carte gravée (cran « Maître »).
  static const Color surfaceEngraved = Color(0xFF241533);

  /// Haut du dégradé de la plaque du dernier cran (« Icône »).
  static const Color surfaceIcon = Color(0xFF2E1A40);

  /// Fond profond des sceaux : c'est lui qui creuse la silhouette.
  static const Color primaryDeep = Color(0xFF4A1580);

  /// Texte posé SUR l'accent orange. Un blanc y passerait sous le seuil.
  static const Color onAccent = Color(0xFF1A0A02);

  /// Dénominateur d'un total (« /1000 »), libellés de 9 points : le gris le
  /// plus en retrait qui reste lisible.
  ///
  /// ALIAS de [darkTextTertiary], à dessein : entre le gris minimal AA sur
  /// la plaque la plus claire ([surfaceIcon]) et [darkTextSecondary], il n'y
  /// a pas la place de deux pas perceptibles — trois rôles y devenaient un
  /// seul gris à l'œil. Il n'existe donc plus de troisième gris : un seul
  /// gris en retrait, mesurable, plutôt que deux nuances indiscernables. Le
  /// nom reste pour l'intention (« ce texte est le plus éteint possible »),
  /// la valeur est UNE.
  static const Color textMuted = darkTextTertiary;

  /// Liseré des surfaces qui ont gagné leur majesté.
  static const Color majestyBorder = Color(0x59C88BFF); // primaryLight .35

  /// Filet gravé à l'intérieur d'un sceau ou d'un cadre.
  static const Color engravedRule = Color(0x8CC88BFF); // primaryLight .55

  /// Piste EN ATTENTE : des tirets, jamais une piste vide. Une jauge à zéro
  /// se lit comme un échec ; des tirets se lisent comme « pas encore ».
  static const Color pendingTrack = Color(0x4DC88BFF); // primaryLight .30

  /// Guillochage : le grain diagonal des surfaces gravées.
  static const Color guilloche = Color(0x0DFFFFFF); // blanc .05

  /// Jauge de progression du titre. Le dégradé est RÉSERVÉ à la carte de
  /// titre : les jauges d'axes sont pleines, sinon plus rien ne hiérarchise.
  static const LinearGradient gauge = LinearGradient(
    colors: [primaryDark, primary, magenta],
    stops: [0, 0.46, 1],
  );

  /// Réponse de quiz au repos : une surface à peine posée sur le fond, et
  /// son filet. Assez pour se lire comme un bouton, assez peu pour que le
  /// choix fait ressorte d'un coup.
  static const Color quizChoiceFill = Color(0x08FFFFFF); // blanc .03
  static const Color quizChoiceBorder = Color(0x14FFFFFF); // blanc .08
  static const Color quizLetterBorder = Color(0x2EFFFFFF); // blanc .18

  /// Cran déjà franchi d'une échelle graduée : l'accent, en retrait, pour
  /// que le cran COURANT reste le seul point chaud.
  static const Color accentSoft = Color(0x8CFF7A45); // accent .55

  /// Filet INTERNE d'une grille : il naît d'un espacement sur ce fond, pas
  /// d'une bordure. Un point plus clair que la bordure extérieure, sinon la
  /// croix disparaît au milieu de la surface.
  static const Color gridRule = Color(0x0FFFFFFF); // blanc .06

  /// Trait d'un jour à venir, dans la série de constance : présent, sourd.
  static const Color pendingBar = Color(0x14FFFFFF); // blanc .08

  /// Creux du pointillé de la journée en cours.
  static const Color pendingBarSoft = Color(0x38C88BFF); // primaryLight .22

  /// Fond du bloc compact de l'accueil : la lumière vient d'un coin, comme
  /// sur une plaque tenue en main. Un aplat y serait une tuile de plus.
  static const RadialGradient compactPlate = RadialGradient(
    center: Alignment(0.76, -1),
    radius: 1.3,
    colors: [surfaceEngraved, darkSurface],
    stops: [0, 0.62],
  );

  /// Avatar d'un compte qui a commencé son histoire. Un compte neuf porte la
  /// surface nue : le dégradé se gagne, comme le reste de l'écran.
  static const LinearGradient avatarMajestic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDeep],
  );

  /// Jauge d'axe : violet PLEIN. Un dégradé y ferait cinq petites cartes de
  /// titre, et l'écran n'aurait plus de hiérarchie.
  static const LinearGradient axisFill = LinearGradient(
    colors: [primary, primary],
  );

  /// Bordure en dégradé des deux derniers crans de majesté.
  static const LinearGradient majestyEdge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xD9ED35A9), Color(0x739B30FF), Color(0x249B30FF)],
    stops: [0, 0.52, 1],
  );

  /// Remplissage d'un sceau : le violet part clair et s'enfonce.
  static const LinearGradient sealFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDark, primaryDeep],
    stops: [0, 0.60, 1],
  );

  /// Dégradé du cartouche d'un titre : le seul sceau qui porte le magenta.
  static const LinearGradient sealTitleFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [magenta, primary, primaryDeep],
    stops: [0, 0.55, 1],
  );

  /// Fond de l'en-tête d'un défi entre amis : la surface qui s'enfonce dans
  /// le violet profond, en diagonale. Violet par règle (CLAUDE.md, règle 9) :
  /// un défi n'est pas une surface de marque. La photographie de la maquette,
  /// quand elle arrivera, se posera fondue par-dessus.
  static const LinearGradient challengeHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkSurface, primaryDeep],
    stops: [0.35, 1],
  );

  /// Halo d'une popup : le violet qui descend du médaillon et s'éteint avant
  /// le texte. Violet par règle (CLAUDE.md, règle 9) : une popup n'est pas
  /// une surface de marque. Son pic ([primaryBadgeBg] sur [darkSurface]) est
  /// mesuré par `app_popup_test.dart` : le texte secondaire y tient AA.
  static const RadialGradient popupHalo = RadialGradient(
    center: Alignment.topCenter,
    radius: 0.9,
    colors: [primaryBadgeBg, primaryCardClear],
  );

  /// Fond de la tuile du manifeste.
  static const LinearGradient manifestoTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x299B30FF), Color(0x1AED35A9)],
  );

  /// Remplissage d'un jour du calendrier selon l'intensité 0..1 (violet).
  static Color heatFill(double intensity) => Color.lerp(
    const Color(0x809B30FF),
    const Color(0xE69B30FF),
    intensity.clamp(0, 1),
  )!;

  // ── Marques tierces (tokens.json → color.vendor) ──────────────────────────
  //
  // Le G de Google du bouton « Continuer avec Google » — et rien d'autre.
  // Ce ne sont PAS des couleurs Carlys : elles ne participent à aucune
  // palette et ne s'emploient dans aucun autre contexte. Un logo tiers ne se
  // recolore pas, pas plus que notre sceau ne se redessine ; les valeurs sont
  // celles des règles d'usage de la marque Google.
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);

  // ── Métaux des ligues (tokens.json → color.league) ──────────────────────
  //
  // Les cinq divisions de ligue, et RIEN d'autre : le blason de division et
  // les couronnes du podium. Arbitrage produit du 23 septembre 2026 : une
  // division porte le nom d'un métal et se reconnaît à sa couleur avant de
  // se lire. Partout ailleurs, l'application reste violette — ces teintes
  // n'entrent dans aucune autre palette, ni surface, ni texte, ni autre
  // récompense. Tant qu'elles étaient à écrire dans un écran, elles étaient
  // cinq valeurs en dur ; ce sont désormais des jetons.
  //
  // Trois tons par métal, du plus clair au plus sombre : le REFLET
  // (`…Light`), le CORPS, l'OMBRE (`…Dark`). Un métal se peint par sa
  // lumière ; en aplat, l'or n'est qu'un jaune. Le corps tient le seuil d'un
  // élément graphique (3:1, WCAG 1.4.11) sur `darkSurface` : c'est lui qui
  // dessine la silhouette. L'ombre, elle, n'est pas garantie : de 2,05
  // (bronze, sous le seuil) à 4,04 (platine) sur `darkSurface`, et seul le
  // platine tient 3:1 sur `surfaceIcon`. Elle ne se pose donc jamais seule
  // sur le fond — elle creuse l'intérieur du blason.
  //
  // Les noms suivent tokens.json, en anglais ; `LeagueDivision` parle
  // français : argent = silver, or = gold, platine = platinum, diamant =
  // diamond.
  static const Color leagueBronzeLight = Color(0xFFF0B48A);
  static const Color leagueBronze = Color(0xFFC27A45);
  static const Color leagueBronzeDark = Color(0xFF6E3B1C);
  static const Color leagueSilverLight = Color(0xFFEEF1F6);
  static const Color leagueSilver = Color(0xFFAEB6C4);
  static const Color leagueSilverDark = Color(0xFF5A6272);
  static const Color leagueGoldLight = Color(0xFFFFE39A);
  static const Color leagueGold = Color(0xFFE5AF37);
  static const Color leagueGoldDark = Color(0xFF8A6412);
  static const Color leaguePlatinumLight = Color(0xFFDDF4F3);
  static const Color leaguePlatinum = Color(0xFF9FCFCF);
  static const Color leaguePlatinumDark = Color(0xFF4B7D80);
  static const Color leagueDiamondLight = Color(0xFFD6ECFF);
  static const Color leagueDiamond = Color(0xFF7DB7F2);
  static const Color leagueDiamondDark = Color(0xFF2F64A8);
}
