import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';

/// Flèche de retour d'en-tête de page — LA même sur toutes les pages
/// poussées (historique, profil, programmes, nutrition…), avec la géométrie
/// de la maquette : icône 23, boîte tactile 44.
///
/// Elle dépile la navigation la plus proche (pile racine ou branche
/// d'onglet) et DISPARAÎT quand il n'y a rien à dépiler — jamais de flèche
/// morte sur un écran de premier niveau.
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.color = AppColors.darkTextSecondary, super.key});

  final Color color;

  /// Géométrie de la maquette : icônes 23, boîte tactile 44.
  static const double _iconSize = 23;
  static const double _tapSize = 44;

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Retour',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: _tapSize,
        height: _tapSize,
      ),
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(AppIcons.back, size: _iconSize, color: color),
    );
  }
}
