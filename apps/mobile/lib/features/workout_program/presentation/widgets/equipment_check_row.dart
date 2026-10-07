import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Une ligne cochable d'une famille de matériel, précédée de son trait.
class EquipmentCheckRow extends StatelessWidget {
  const EquipmentCheckRow({
    required this.label,
    required this.semantics,
    required this.checked,
    required this.onTap,
    this.icon,
    this.strong = false,
    super.key,
  });

  final String label;
  final String semantics;
  final bool checked;
  final VoidCallback onTap;
  final IconData? icon;

  /// La ligne « Tout cocher » : en couleur d'action, sans glyphe.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: AppColors.darkBorder),
        Semantics(
          button: true,
          // « Tout cocher » est une action, pas un état : « Tout décocher,
          // sélectionné » se contredisait.
          selected: strong ? null : checked,
          label: semantics,
          // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
          onTap: onTap,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: AppColors.primaryLight),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: strong
                            ? AppColors.primaryLight
                            : AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    checked ? AppIcons.checkCircle : AppIcons.uncheckedCircle,
                    size: 20,
                    color: checked
                        ? AppColors.primaryLight
                        : AppColors.darkTextTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
