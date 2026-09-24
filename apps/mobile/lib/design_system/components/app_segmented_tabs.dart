import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../motion/app_motion.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Un onglet de [AppSegmentedTabs] : son libellé, et un compte facultatif
/// (les demandes d'ami en attente) qui se lit sans ouvrir l'onglet.
class AppSegment {
  const AppSegment(this.label, {this.count = 0});

  final String label;

  /// Zéro : aucune pastille. Une pastille qui dirait « 0 » attirerait l'œil
  /// vers rien.
  final int count;
}

/// Des onglets SEGMENTÉS : une piste, et l'onglet choisi peint en violet.
///
/// Le premier contrôle de ce genre du design system (la Communauté, refonte
/// de septembre 2026). Les autres sélecteurs de l'application sont des
/// rangées de pastilles ; celui-ci dit qu'on change de PAGE, pas de filtre.
///
/// Chaque onglet répond sur toute la hauteur de la piste
/// ([AppSpacing.touchTarget]) : la pastille violette n'est que l'ornement
/// de l'onglet choisi, jamais la seule zone qui répond au doigt.
///
/// La pastille porte le violet du bouton principal ([AppColors.cta]), celui
/// des surfaces sous un libellé blanc. Elle portait [AppColors.violetRamp],
/// qui s'éclaircit vers la droite jusqu'à 3,86:1 sous le blanc : le bord
/// droit de « Ligue » passait sous 4,5 sur un écran de 360 points.
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<AppSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.fullAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < segments.length; index++)
            Expanded(
              child: _Segment(
                segment: segments[index],
                position: index,
                total: segments.length,
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.position,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final AppSegment segment;
  final int position;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      segment.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.subheading.copyWith(
        color: selected ? AppColors.neutral0 : AppColors.darkTextSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: segment.count > 0
          ? '${segment.label}, ${segment.count} en attente'
          : segment.label,
      hint: 'Onglet ${position + 1} sur $total',
      // Le libellé est réécrit (le compte s'y dit en mots) : l'action doit
      // l'être aussi, sans quoi l'exclusion emporte le geste de l'InkWell.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: AppSpacing.touchTarget,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.tab),
              curve: AppMotion.standard,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.cta : null,
                borderRadius: AppRadius.fullAll,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: segment.count > 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: label),
                        const SizedBox(width: AppSpacing.xxs + 2),
                        _CountDot(count: segment.count),
                      ],
                    )
                  : label,
            ),
          ),
        ),
      ),
    );
  }
}

/// Le compte d'un onglet : l'accent orange, seul signe d'attente de la piste.
class _CountDot extends StatelessWidget {
  const _CountDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs + 2,
        vertical: AppSpacing.xxs / 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTypography.labelMono.copyWith(
          color: AppColors.onAccent,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
