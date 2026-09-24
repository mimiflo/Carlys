import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Barre basse de l'éditeur : rappel du programme composé, annulation et
/// enregistrement — l'unique action accent de l'écran.
///
/// « Enregistrer » est désactivé tant que le modèle n'est pas enregistrable
/// (nom vide ou aucun exercice) : les mêmes règles que côté serveur, mais
/// **avant** l'écriture, pour ne jamais transformer une saisie hors ligne en
/// refus définitif à la synchronisation.
class TemplateEditorBottomBar extends StatelessWidget {
  const TemplateEditorBottomBar({
    required this.exercisesCount,
    required this.plannedSetsCount,
    required this.canSave,
    required this.saving,
    required this.onSave,
    required this.onCancel,
    super.key,
  });

  final int exercisesCount;
  final int plannedSetsCount;
  final bool canSave;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AppTranslucentBar(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.md + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _summary(),
              style: AppTypography.labelMono.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: AppSpacing.xs),
                // L'unique action accent de l'écran. Désactivé, le bouton
                // retombe sur la plaque sombre ; en enregistrement, il y
                // pose un indicateur au violet du thème.
                Expanded(
                  child: AppCtaButton(
                    label: 'Enregistrer',
                    icon: AppIcons.check,
                    onPressed: canSave ? onSave : null,
                    isLoading: saving,
                    semanticLabel: 'Enregistrer le modèle',
                    loadingLabel: 'Enregistrement',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _summary() {
    if (exercisesCount == 0) {
      return 'AUCUN EXERCICE';
    }
    return '${formatThousands(exercisesCount)} EXERCICE'
        '${exercisesCount > 1 ? 'S' : ''} · '
        '${formatThousands(plannedSetsCount)} SÉRIE'
        '${plannedSetsCount > 1 ? 'S' : ''} PRÉVUE'
        '${plannedSetsCount > 1 ? 'S' : ''}';
  }
}
