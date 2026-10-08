import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../typography/app_typography.dart';

/// Un lien d'action violet suivi de son chevron : « Voir mes mesures › »,
/// « Voir le parcours › ». Il ouvre une suite ; il ne valide rien — c'est
/// le rôle d'`AppButton`.
class AppLinkButton extends StatelessWidget {
  const AppLinkButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: const Icon(AppIcons.chevronRight),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        padding: EdgeInsets.zero,
        textStyle: AppTypography.subheading,
      ),
    );
  }
}
