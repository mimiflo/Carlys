import 'package:flutter/material.dart';

import '../theme/app_dark_theme.dart';

/// LA PAGE SOMBRE de Carlys : un [Scaffold] au fond sombre du thème, et le
/// thème sombre à tout ce qu'il porte.
///
/// L'application est sombre par dessin, et ses écrans le sont sous tous les
/// réglages. Chacun peignait pourtant son `Scaffold` en `darkBackground` à la
/// main, en laissant le thème AMBIANT à son contenu : sous le thème Clair,
/// les cartes y devenaient blanches, la barre d'application claire, et un
/// bouton contour y prenait le violet profond pensé pour une page claire.
/// Le fond et le thème vont ensemble — ici, ils ne se séparent plus.
///
/// Le fond est celui du thème LU SOUS [AppDarkTheme]
/// ([AppDarkTheme.pageColorOf]) : `darkBackground` sous les réglages Sombre
/// et Clair, le noir pur de `oledBackground` sous « Sombre OLED ». Il était
/// peint en `darkBackground` en dur : le réglage OLED, qui promet un fond
/// noir, ne changeait alors rien sur 42 écrans. Ce qui se fond dans la
/// page (voiles des scènes, fondu d'une image) lit le même fond.
///
/// `dark_surfaces_test.dart` refuse un `Scaffold` peint en
/// `darkBackground` hors du design system. Les écrans qui SUIVENT le thème
/// (connexion utilitaire, sessions, détail d'une séance) gardent le
/// `Scaffold` ordinaire.
class AppDarkScaffold extends StatelessWidget {
  const AppDarkScaffold({required this.body, this.appBar, super.key});

  final Widget body;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return AppDarkTheme(
      child: Scaffold(
        backgroundColor: AppDarkTheme.pageColorOf(context),
        appBar: appBar,
        body: body,
      ),
    );
  }
}
