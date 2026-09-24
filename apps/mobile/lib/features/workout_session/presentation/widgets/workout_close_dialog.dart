import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Confirmation de clôture (ou d'abandon) d'une séance.
///
/// Quand la séance suivait un programme, [planSummary] ajoute un **constat**
/// — « 9 séries sur 12 prévues » —, jamais une alerte ni un reproche : une
/// séance écourtée reste une séance faite.
///
/// Ce constat sous le message est ce qui la sort de `showAppConfirm` : elle
/// passe par la porte générique, dans la même coquille. Rend `true` si l'on
/// confirme, `false` si l'on renonce, `null` si l'on touche le voile ou fait
/// retour.
Future<bool?> showWorkoutCloseDialog(
  BuildContext context, {
  required bool abandon,
  String? planSummary,
}) {
  return showAppDialog<bool>(
    context,
    builder: (dialogContext) => AppPopupCard(
      icon: abandon ? AppIcons.confirmLeave : AppIcons.confirmFinish,
      title: abandon ? 'Abandonner la séance ?' : 'Terminer la séance ?',
      message: abandon
          ? 'La séance sera marquée comme abandonnée.'
          : 'Tes séries sont enregistrées et seront synchronisées.',
      content: planSummary == null
          ? null
          : Center(
              child: AppPill(
                label: planSummary,
                tone: AppPillTone.primary,
                mono: true,
              ),
            ),
      actions: [
        AppButton(
          label: 'Confirmer',
          // Abandonner renonce à la séance : le bouton le dit en rouge.
          // Terminer la clôt normalement : c'est l'action principale.
          variant: abandon
              ? AppButtonVariant.destructive
              : AppButtonVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        AppButton(
          label: 'Annuler',
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
}
