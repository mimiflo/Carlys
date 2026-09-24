import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';

enum AppBadgeVariant { neutral, primary, accent, warning }

/// Pastille d'information courte (difficulté, type, Premium…).
///
/// Chaque variante tient AA (4,5:1) sur les fonds où une pastille se pose,
/// dans les TROIS thèmes : `contrast_pairs_test.dart` le mesure. Le thème
/// clair a ses propres encres pour deux variantes : sur une teinte pâle, le
/// violet vif n'y tenait que 3,85 et l'ambre 1,83.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final light = colorScheme.brightness == Brightness.light;
    final (background, foreground) = switch (variant) {
      AppBadgeVariant.neutral => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
      // En clair, le violet PROFOND sur une teinte plus légère : 5,01 sur le
      // fond de page, 4,76 même sur la surface alternée.
      AppBadgeVariant.primary => (
        colorScheme.primary.withValues(alpha: light ? 0.10 : 0.14),
        light ? AppColors.primaryDark : colorScheme.primary,
      ),
      AppBadgeVariant.accent => (AppColors.accent, AppColors.neutral950),
      // En clair, l'ambre ne se lit pas sur sa propre teinte : c'est la
      // teinte qui dit « attention », et l'encre de la variante accent qui
      // se lit (16,66).
      AppBadgeVariant.warning => (
        AppColors.warning.withValues(alpha: 0.16),
        light ? AppColors.neutral950 : AppColors.warning,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
