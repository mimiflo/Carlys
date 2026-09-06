import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Feuille de confirmation d'un geste qui retire ou éloigne quelqu'un.
///
/// Rend `true` si la personne confirme, `false` si elle renonce ou referme
/// la feuille : un geste de retrait ne part jamais d'un simple appui de menu.
Future<bool> showCommunityConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showAppSheet<bool>(
    context,
    builder: (_) => _ConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    ),
  );
  return confirmed ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.subheading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: confirmLabel,
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Annuler',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
