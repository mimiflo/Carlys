import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Des tuiles-choix de même largeur : « 4 » séances, « 60 min »… La choisie
/// porte le dégradé du bouton principal, les autres la surface alternée.
///
/// Dans une `AppAdaptiveGrid` : cinq par rangée sur un téléphone, moins sur
/// 320 points ou en texte agrandi. Une rangée fixe y descendait sous la cible
/// tactile (42 points), et rétrécir le texte pour qu'il tienne annulait le
/// réglage de taille de l'appareil.
class ChoiceTiles extends StatelessWidget {
  const ChoiceTiles({
    required this.choices,
    required this.current,
    required this.onChoose,
    required this.labelOf,
    super.key,
  });

  /// Presets proposés ; une valeur SERVEUR hors presets (bornes du contrat
  /// plus larges) est ajoutée en fin de rangée, sélectionnée — sans quoi
  /// l'écran la cachait et le premier tap l'écrasait en silence.
  final List<int> choices;
  final int? current;
  final ValueChanged<int> onChoose;
  final String Function(int value) labelOf;

  /// « 90 min » en mono et ses marges : cinq tuiles tiennent sur 393 points.
  static const double _minTileWidth = 56;

  @override
  Widget build(BuildContext context) {
    final affiches = [
      ...choices,
      if (current != null && !choices.contains(current)) current!,
    ];
    return AppAdaptiveGrid(
      minItemWidth: _minTileWidth,
      children: [
        for (final value in affiches)
          _ChoiceTile(
            label: labelOf(value),
            selected: value == current,
            onTap: () => onChoose(value),
          ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      // Le fond SOUS un `Material` transparent : l'encre de l'appui se
      // peint par-dessus le dégradé au lieu de passer dessous.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: selected ? AppColors.cta : null,
          color: selected ? null : AppColors.darkSurfaceAlt,
          borderRadius: AppRadius.mdAll,
          border: selected ? null : Border.all(color: AppColors.darkBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.mdAll,
            // Le voile SOMBRE des boutons : le clair du thème pâlissait le
            // violet sous le libellé blanc.
            overlayColor: AppButton.stateOverlay,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMono.copyWith(
                      color: selected
                          ? AppColors.neutral0
                          : AppColors.darkTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
