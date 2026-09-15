import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../spacing/app_spacing.dart';

/// La porte d'entrée vers le POURQUOI d'une donnée affichée.
///
/// Il n'existait AUCUNE affordance d'explication dans le design system : ni
/// infobulle, ni icône d'information branchée sur un chiffre. L'écran
/// Nutrition annonçait « IMC 27,3 » et « Surpoids » sans un mot, alors que la
/// promesse de marque est l'inverse — « Carlys ne dit jamais seulement quoi
/// faire, il explique toujours pourquoi ».
///
/// Ce composant ne connaît AUCUN contenu : il ouvre ce qu'on lui demande
/// d'ouvrir. Les explications sont du domaine, pas du design system.
///
/// La cible tactile fait [AppSpacing.touchTarget] alors que l'icône fait
/// [glyphSize] — c'est le même arbitrage que sur `AppPill` et les flèches de
/// taille : l'ornement est discret, la zone qui répond ne l'est pas.
///
/// Il sert quand le glyphe EST le bouton. Quand la donnée porte déjà une
/// surface tapable assez grande (une tuile, une ligne de macro), c'est elle
/// qui prend le geste et le glyphe redevient un simple ornement : voir
/// `AppStatTile.onExplain`. Deux boutons imbriqués pour une seule intention
/// seraient un piège au doigt comme au lecteur d'écran.
class AppExplainButton extends StatelessWidget {
  const AppExplainButton({
    required this.onPressed,
    required this.aProposDe,
    this.size = glyphSize,
    super.key,
  });

  /// Taille du glyphe d'explication, partout où il apparaît — y compris
  /// quand il n'est qu'un ornement posé sur une surface tapable.
  static const double glyphSize = 16;

  final VoidCallback onPressed;

  /// Ce que l'explication concerne, pour les lecteurs d'écran : le libellé
  /// seul (« Pourquoi ? ») ne dit pas de QUOI on parle quand la page en
  /// contient six.
  final String aProposDe;

  /// Taille de l'icône. La zone tactile, elle, ne change pas.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Explication : $aProposDe',
      child: InkResponse(
        onTap: onPressed,
        radius: AppSpacing.touchTarget / 2,
        child: SizedBox(
          height: AppSpacing.touchTarget,
          width: AppSpacing.touchTarget,
          child: Center(
            child: Icon(
              AppIcons.info,
              size: size,
              color: AppColors.darkTextTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
