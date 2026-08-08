import 'dart:ui';

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

  /// Géométrie de la maquette : voile flouté à 20, fond à 90 %.
  static const double _blur = 20;
  static const double _veilAlpha = 0.9;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkBackground.withValues(alpha: _veilAlpha),
            border: const Border(
              top: BorderSide(color: AppColors.darkBorder),
            ),
          ),
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
                  style: AppTypography.labelMono
                      .copyWith(color: AppColors.darkTextTertiary),
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
  static const double _glowBlur = 30;
  static const double _glowSpread = -12;
  static const double _glowOffset = 12;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Enregistrer le modèle',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.buttonAll,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.7),
                    blurRadius: _glowBlur,
                    spreadRadius: _glowSpread,
                    offset: const Offset(0, _glowOffset),
                  ),
                ]
              : const [],
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.darkBackground,
            disabledBackgroundColor: AppColors.darkSurface,
            disabledForegroundColor: AppColors.darkIconInactive,
            textStyle:
                AppTypography.subheading.copyWith(fontWeight: FontWeight.w700),
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
