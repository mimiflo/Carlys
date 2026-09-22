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
                Expanded(
                  child: _SaveButton(
                    enabled: canSave && !saving,
                    saving: saving,
                    onPressed: onSave,
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

/// Unique action accent de l'écran.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  static const double _iconSize = 19;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Enregistrer le modèle',
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Le dégradé (et son halo) ne s'affichent qu'actif : désactivé, le
          // bouton retombe sur la plaque sombre, comme avant.
          gradient: enabled ? AppColors.cta : null,
          color: enabled ? null : AppColors.darkSurface,
          borderRadius: AppRadius.buttonAll,
          boxShadow: enabled ? AppShadows.ctaGlow() : const [],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.neutral0,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: AppColors.darkIconInactive,
            shadowColor: Colors.transparent,
            textStyle: AppTypography.subheading.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: enabled ? onPressed : null,
          child: saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.darkBackground,
                    semanticsLabel: 'Enregistrement',
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.check, size: _iconSize),
                    SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Enregistrer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
