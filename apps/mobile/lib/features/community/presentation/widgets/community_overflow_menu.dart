import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Une entrée du menu « plus d'options » d'une carte communautaire.
class CommunityMenuAction {
  const CommunityMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Geste qui retire ou éloigne quelqu'un : rendu dans la couleur de danger,
  /// pour que le doigt ne le confonde pas avec un simple réglage.
  final bool destructive;
}

/// Le menu discret des cartes d'ami et d'encouragement : trois points, une
/// cible tactile pleine ([AppSpacing.touchTarget]) et une infobulle nommant
/// la personne, pour qu'un lecteur d'écran ne récite pas « options » quatre
/// fois de suite.
class CommunityOverflowMenu extends StatelessWidget {
  const CommunityOverflowMenu({
    required this.tooltip,
    required this.actions,
    super.key,
  });

  final String tooltip;
  final List<CommunityMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CommunityMenuAction>(
      tooltip: tooltip,
      icon: const Icon(
        Icons.more_vert_rounded,
        color: AppColors.darkTextTertiary,
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSpacing.touchTarget),
      ),
      color: AppColors.darkSurfaceAlt,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (action) => action.onSelected(),
      itemBuilder: (_) => [
        for (final action in actions)
          PopupMenuItem<CommunityMenuAction>(
            value: action,
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: 20,
                  color: action.destructive
                      ? AppColors.danger
                      : AppColors.darkTextSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  action.label,
                  style: AppTypography.body.copyWith(
                    color: action.destructive
                        ? AppColors.danger
                        : AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
