import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../spacing/app_spacing.dart';

/// Flèche de retour d'en-tête de page — LA même sur toutes les pages
/// poussées (historique, profil, programmes, nutrition…), avec l'icône de
/// la maquette (23) dans la boîte tactile du design system.
///
/// Elle dépile la navigation la plus proche (pile racine ou branche
/// d'onglet) et DISPARAÎT quand il n'y a rien à dépiler — jamais de flèche
/// morte sur un écran de premier niveau.
class AppBackButton extends StatelessWidget {
  const AppBackButton({this.color = AppColors.darkTextSecondary, super.key});

  final Color color;

  /// Icône de la maquette. La boîte tactile est [AppSpacing.touchTarget],
  /// pas une taille propre à ce bouton.
  static const double _iconSize = 23;

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Retour',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
      ),
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(AppIcons.back, size: _iconSize, color: color),
    );
  }
}
