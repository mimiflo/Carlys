import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Une option de [AppChoicePills] : la valeur, et ce qui s'écrit.
class AppChoice<T> {
  const AppChoice(this.value, this.label, {this.semanticLabel});

  final T value;

  /// Court : « g », « ml », « portion ».
  final String label;

  /// Ce que le lecteur d'écran dit à la place d'une abréviation
  /// (« grammes » pour « g »).
  final String? semanticLabel;
}

/// Un CHOIX COMPACT parmi quelques valeurs courtes : des pastilles côte à
/// côte, la choisie peinte au violet plein (l'unité d'une quantité : g | ml
/// | portion | pièce).
///
/// Compact parce qu'il se pose à côté d'un titre de carte, là où des
/// onglets segmentés (`AppSegmentedTabs`, qui disent qu'on change de PAGE)
/// seraient trop lourds et des cartes de choix trop grandes. La pastille
/// choisie porte le dégradé du bouton principal ([AppColors.cta]) sous un
/// libellé blanc ; les autres, la teinte neutre des pastilles.
///
/// [onSelected] nul VERROUILLE le choix : la valeur choisie reste peinte
/// (elle est vraie, simplement pas modifiable ici), les autres s'éteignent.
/// Chaque pastille est un ornement haut de 32 points, au moins aussi large
/// que la cible tactile qui l'entoure.
class AppChoicePills<T> extends StatelessWidget {
  const AppChoicePills({
    required this.choices,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<AppChoice<T>> choices;
  final T selected;
  final ValueChanged<T>? onSelected;

  static const double _pillHeight = 32;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xxs,
      children: [
        for (final choice in choices)
          _Pill(
            label: choice.label,
            semanticLabel: choice.semanticLabel ?? choice.label,
            selected: choice.value == selected,
            onTap: onSelected == null ? null : () => onSelected!(choice.value),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ink = selected
        ? AppColors.neutral0
        : enabled
        ? AppColors.neutralBadgeText
        : AppColors.darkIconInactive;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      // La zone qui répond au doigt est la boîte ENTIÈRE, haute d'une cible
      // tactile ; la pastille n'en est que l'ornement, centré (même
      // mécanique qu'`AppPill`).
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Une pastille « g » est plus étroite que le doigt : la boîte, elle,
        // ne descend jamais sous la cible tactile, en largeur non plus.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.touchTarget,
            minHeight: AppSpacing.touchTarget,
            maxHeight: AppSpacing.touchTarget,
          ),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: selected ? AppColors.cta : null,
                color: selected ? null : AppColors.neutralBadgeBg,
                borderRadius: AppRadius.fullAll,
              ),
              child: ConstrainedBox(
                // Au moins aussi large que la cible tactile : sinon « g » et
                // « ml », plus étroits que le doigt, flottaient au milieu
                // d'une boîte invisible, et l'écart entre deux pastilles
                // variait d'une paire à l'autre. Pastille et cible ont
                // désormais la même largeur : l'écart est partout
                // `AppSpacing.xxs`.
                constraints: const BoxConstraints(
                  minHeight: AppChoicePills._pillHeight,
                  minWidth: AppSpacing.touchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      label,
                      style: AppTypography.label.copyWith(
                        color: ink,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
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
