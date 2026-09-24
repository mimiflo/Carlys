import 'package:flutter/material.dart';

import 'app_theme.dart';

/// LE THÈME DE CE QUI EST PEINT EN SOMBRE, quel que soit le réglage.
///
/// L'application est sombre par dessin : la plupart des écrans peignent leur
/// fond en `AppColors.darkBackground`, les feuilles en `darkSurface` ou
/// `darkSurfaceAlt`, les barres basses un verre sombre — sous le thème Clair
/// aussi. Or tout ce qui se pose dessus lisait le thème AMBIANT : sous le
/// Clair, le violet profond d'un bouton contour (3,35:1 sur la page sombre),
/// la plaque BLANCHE d'un appel à l'action désactivé dans une barre sombre.
/// Et choisir l'encre selon le thème ne peut pas suffire : aucun violet ne
/// tient 4,5:1 à la fois sur la page claire et sur la page sombre. C'est au
/// thème de dire ce qui est peint — ce widget le lui fait dire.
///
/// Il enveloppe ce qui PEINT le fond sombre : le `Scaffold` d'un écran
/// sombre, une feuille (`showAppSheet`), une barre en verre
/// (`AppTranslucentBar`), une popup (`AppPopupCard`).
///
/// Sous un thème SOMBRE (sombre ou OLED), il transmet le thème ambiant tel
/// quel : rien ne change. Sous le Clair, il impose [theme], celui que
/// l'application applique en mode sombre. Le widget [Theme] est posé dans les
/// deux cas, seule sa donnée change : basculer le réglage ne reconstruit pas
/// le sous-arbre — ni défilement ni saisie perdus.
class AppDarkTheme extends StatelessWidget {
  const AppDarkTheme({required this.child, super.key});

  final Widget child;

  /// Le thème sombre, construit une fois : deux `AppTheme.dark()` sont des
  /// objets distincts, et reconstruire le thème à chaque passage réveillerait
  /// tout ce qui en dépend.
  static final ThemeData theme = AppTheme.dark();

  @override
  Widget build(BuildContext context) {
    final ambient = Theme.of(context);
    return Theme(
      data: ambient.brightness == Brightness.dark ? ambient : theme,
      child: child,
    );
  }
}
