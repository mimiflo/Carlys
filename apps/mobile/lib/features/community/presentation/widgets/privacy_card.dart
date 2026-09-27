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
    // UN interrupteur, libellé par son titre et sa précision : sans cette
    // fusion, l'état et le geste de la bascule remontaient jusqu'à
    // l'élément de liste qui porte tout l'onglet Amis — lu d'un bloc comme
    // un interrupteur, et un double-tap sur le nom d'une amie coupait le
    // partage.
    return AppCard(
      child: MergeSemantics(
        child: Row(
          children: [
            const Icon(AppIcons.lock, color: AppColors.primaryLight),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Partager ma progression',
                    style: AppTypography.subheading.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  Text(
                    'Ta série et tes séances de la semaine, visibles par tes '
                    'amis. Désactivé : ils ne voient que ton nom.',
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextTertiary,
                    ),
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
      ),
    );
  }
}
