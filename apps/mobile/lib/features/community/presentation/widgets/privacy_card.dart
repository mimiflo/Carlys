import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Le réglage de confidentialité de la communauté : partager (ou non) sa
/// progression avec ses amis. À faux, ils ne voient que le nom.
class PrivacyCard extends StatelessWidget {
  const PrivacyCard({
    required this.sharesProgress,
    required this.onChanged,
    super.key,
  });

  /// `null` tant que la préférence n'est pas chargée (interrupteur inactif).
  final bool? sharesProgress;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.primaryLight),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partager ma progression',
                  style: AppTypography.subheading
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                Text(
                  'Ta série et tes séances de la semaine, visibles par tes '
                  'amis. Désactivé : ils ne voient que ton nom.',
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Switch(
            value: sharesProgress ?? true,
            onChanged: sharesProgress == null ? null : onChanged,
          ),
        ],
      ),
    );
  }
}
