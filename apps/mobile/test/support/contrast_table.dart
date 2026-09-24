import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast.dart';

/// LA MÉCANIQUE DES TABLES DE CONTRASTE : poser un composant, LIRE ce qu'il
/// peint, mesurer.
///
/// Une ligne pose un composant dans un état et rend ses [Paire]s : la
/// couleur résolue du texte ou de l'icône, ce qui est peint dessous (le
/// dégradé ou l'aplat, composé sur ce qu'il recouvre), le seuil WCAG 2.2 AA
/// — 4,5:1 pour un texte, 3:1 pour une icône. Rien n'est recopié : si un
/// composant change de couleur, c'est la nouvelle qui est mesurée.
///
/// Un dégradé se mesure à ses ARRÊTS, jamais à sa moyenne : sous un texte
/// clair, ce sont eux qui encadrent toute la course (voir `stopsOf`).
///
/// Le voile d'un état est celui que le composant PEINT : la propriété que
/// son `InkWell` reçoit, où Material a déjà résolu le style du widget, celui
/// du thème et ses propres défauts — pas seulement le style écrit à la main.
///
/// Deux tables s'en servent : `contrast_pairs_test.dart` (les composants du
/// design system) et `dark_surfaces_test.dart` (ce qui se pose sur les
/// surfaces peintes en sombre sous tous les réglages).

/// Une paire mesurée : ce qui s'écrit, ce qui est peint dessous (opaque),
/// le seuil qui s'applique.
typedef Paire = ({String quoi, Color encre, Color fond, double seuil});

/// Le contraste que l'œil reçoit : l'encre translucide composée sur son fond.
double ratioDe(Paire paire) =>
    contrast(over(paire.encre, paire.fond), paire.fond);

/// Une ligne de table : un composant dans un état, et ce qu'on y lit.
class Ligne {
  const Ligne(this.nom, this.mesurer);

  final String nom;
  final Future<List<Paire>> Function(WidgetTester tester) mesurer;
}

/// Un test par ligne ; un manquement cite le ratio, l'encre et le fond.
void mesurerLaTable(List<Ligne> table) {
  for (final ligne in table) {
    testWidgets(ligne.nom, (tester) async {
      final paires = await ligne.mesurer(tester);
      expect(paires, isNotEmpty, reason: 'une ligne qui ne mesure rien');
      final manquements = [
        for (final paire in paires)
          if (ratioDe(paire) < paire.seuil)
            '${paire.quoi} : ${ratioDe(paire).toStringAsFixed(2)}:1 '
                '(seuil ${paire.seuil}) — encre ${hex(paire.encre)}, '
                'fond ${hex(paire.fond)}',
      ];
      expect(manquements, isEmpty, reason: manquements.join('\n'));
    });
  }
}

/// Les trois thèmes de l'application.
const themesMesures = <String, ThemeData Function()>{
  'sombre': AppTheme.dark,
  'clair': AppTheme.light,
  'OLED': AppTheme.oledDark,
};

/// Les trois états d'un bouton qui posent un voile sur son fond.
const _etats = <String, Set<WidgetState>>{
  'survol': {WidgetState.hovered},
  'focus': {WidgetState.focused},
  'appui': {WidgetState.pressed},
};

/// Les paires d'un libellé (ou d'une icône, au [seuil] graphique) posé sur
/// [fond], au repos puis sous chacun des [voiles] d'état. À l'appui,
/// l'éclaboussure se pose EN PLUS du voile, près du doigt : elle est
/// mesurée aussi — le voile d'appui lui-même, sauf [eclaboussure] à part.
List<Paire> etatsSur(
  String quoi,
  Color encre,
  Color fond,
  WidgetStateProperty<Color?>? voiles, {
  double seuil = wcagText,
  Color? eclaboussure,
}) {
  final appui = voiles?.resolve({WidgetState.pressed});
  return [
    (quoi: '$quoi au repos', encre: encre, fond: fond, seuil: seuil),
    for (final MapEntry(key: etat, value: cles) in _etats.entries)
      if (voiles?.resolve(cles) case final voile?)
        (
          quoi: '$quoi, $etat',
          encre: encre,
          fond: over(voile, fond),
          seuil: seuil,
        ),
    if (appui != null)
      (
        quoi: '$quoi, appui et éclaboussure',
        encre: encre,
        fond: over(eclaboussure ?? appui, over(appui, fond)),
        seuil: seuil,
      ),
  ];
}

/// Les voiles d'état que le bouton PEINT : ceux de son `InkWell`, où
/// Material a résolu le style du widget, celui du thème et ses défauts.
WidgetStateProperty<Color?> voilesDe(WidgetTester tester, Finder bouton) =>
    tester
        .widget<InkWell>(
          find.descendant(of: bouton, matching: find.byType(InkWell)).first,
        )
        .overlayColor!;

/// Les voiles qu'un `InkWell` posé à la main PEINT, résolus comme il les
/// résout lui-même : son `overlayColor`, puis ses propres couleurs, puis
/// celles du thème. Et son éclaboussure, à part : sans `overlayColor`, ce
/// n'est pas son voile d'appui mais la `splashColor` du thème.
({WidgetStateProperty<Color?> voiles, Color eclaboussure}) voilesDeLEncre(
  WidgetTester tester,
  Finder encre,
) {
  final puits = tester.widget<InkWell>(encre);
  final theme = Theme.of(tester.element(encre));
  Color? propre(WidgetState etat) => puits.overlayColor?.resolve({etat});
  return (
    voiles: WidgetStateProperty<Color?>.fromMap({
      WidgetState.hovered:
          propre(WidgetState.hovered) ?? puits.hoverColor ?? theme.hoverColor,
      WidgetState.focused:
          propre(WidgetState.focused) ?? puits.focusColor ?? theme.focusColor,
      WidgetState.pressed:
          propre(WidgetState.pressed) ??
          puits.highlightColor ??
          theme.highlightColor,
    }),
    eclaboussure:
        propre(WidgetState.pressed) ?? puits.splashColor ?? theme.splashColor,
  );
}

/// Pose [composant] au centre d'une page, dans le thème demandé.
Future<void> poser(
  WidgetTester tester,
  Widget composant, {
  ThemeData Function() theme = AppTheme.dark,
  bool enBoucle = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme(),
      home: Scaffold(body: Center(child: composant)),
    ),
  );
  await attendre(tester, enBoucle: enBoucle);
}

/// Attend le repos. Un indicateur de chargement tourne sans fin : [enBoucle]
/// remplace alors l'attente du repos par des images rendues, assez pour
/// qu'une feuille ait fini de monter.
Future<void> attendre(WidgetTester tester, {bool enBoucle = false}) async {
  if (enBoucle) {
    await tester.pump();
    await tester.pump(AppMotion.slow);
    await tester.pump(AppMotion.slow);
  } else {
    await tester.pumpAndSettle();
  }
}

/// La couleur RENDUE d'un texte ou d'une icône, thème et style hérité
/// compris.
Color encreDe(WidgetTester tester, Finder texte) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: texte, matching: find.byType(RichText)).first,
    )
    .text
    .style!
    .color!;

/// Le dégradé le plus proche SOUS [cible].
Gradient degradeSous(WidgetTester tester, Finder cible) =>
    _decorationSous(tester, cible, (d) => d.gradient != null).gradient!;

/// L'aplat le plus proche SOUS [cible] (un voile d'appui, une pastille, la
/// plaque d'un appel à l'action désactivé).
Color voileSous(WidgetTester tester, Finder cible) =>
    _decorationSous(tester, cible, (d) => d.color != null).color!;

BoxDecoration _decorationSous(
  WidgetTester tester,
  Finder cible,
  bool Function(BoxDecoration decoration) convient,
) {
  final boite = find
      .ancestor(
        of: cible,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              convient(w.decoration as BoxDecoration),
        ),
      )
      .first;
  return tester.widget<DecoratedBox>(boite).decoration as BoxDecoration;
}

/// La couleur que le `Material` d'un bouton peint réellement (état compris).
Color materielDe(WidgetTester tester, Finder bouton) =>
    tester
        .widget<Material>(
          find.descendant(of: bouton, matching: find.byType(Material)).first,
        )
        .color ??
    Colors.transparent;
