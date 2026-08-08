import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Confirmation de clôture (ou d'abandon) d'une séance.
///
/// Quand la séance suivait un programme, [planSummary] ajoute un **constat**
/// — « 9 séries sur 12 prévues » —, jamais une alerte ni un reproche : une
/// séance écourtée reste une séance faite.
Future<bool?> showWorkoutCloseDialog(
  BuildContext context, {
  required bool abandon,
  String? planSummary,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(abandon ? 'Abandonner la séance ?' : 'Terminer la séance ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            abandon
                ? 'La séance sera marquée comme abandonnée.'
                : 'Vos séries sont enregistrées et seront synchronisées.',
          ),
          if (planSummary != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppPill(
              label: planSummary,
              tone: AppPillTone.primary,
              mono: true,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
}
