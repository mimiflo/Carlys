import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// En-tête de l'historique : titre à gauche, icône calendrier à droite qui
/// ouvre le sélecteur de mois (la maquette n'a pas de chevrons de mois).
class HistoryHeader extends StatelessWidget {
  const HistoryHeader({required this.onPickMonth, super.key});

  final VoidCallback onPickMonth;

  /// Géométrie de la maquette : icône 23, zone tactile élargie à gauche.
  static const double _iconSize = 23;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppBackButton(),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            'Historique',
            style: AppTypography.display.copyWith(
              fontSize: 27,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Choisir le mois affiché',
          child: GestureDetector(
            onTap: onPickMonth,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                0,
                AppSpacing.sm,
              ),
              child: Icon(
                AppIcons.calendar,
                size: _iconSize,
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
