import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// En-tête du coach : la porte de sortie à gauche, la marque au centre.
///
/// Partagé par la conversation ET par ses états d'attente ou d'erreur. Un
/// coach qui n'a pas pu s'ouvrir est précisément le moment où l'on veut
/// repartir : sans flèche, il faudrait ressortir par la barre d'onglets,
/// donc quitter Training pour y revenir.
///
/// La flèche est celle du design system : elle dépile la navigation la plus
/// proche et disparaît d'elle-même s'il n'y a rien derrière. Le coach s'ouvre
/// depuis le hub Training, il y a donc un écran à retrouver ; le jour où il
/// redeviendrait la racine d'un onglet, rien à changer ici.
class CoachHeader extends StatelessWidget {
  const CoachHeader({super.key});

  /// Le bouton de retour et son symétrique à droite : sans le second, le titre
  /// n'est pas centré sur la page mais sur ce qui reste.
  static const double _sideWidth = AppSpacing.touchTarget;
  static const double _markSize = 18;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const SizedBox(width: _sideWidth, child: AppBackButton()),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  AppIcons.coach,
                  size: _markSize,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Coach IA',
                  style: AppTypography.heading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _sideWidth),
        ],
      ),
    );
  }
}
