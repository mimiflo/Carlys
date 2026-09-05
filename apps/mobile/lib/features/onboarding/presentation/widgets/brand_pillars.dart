import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Les quatre univers Carlys, en vignettes.
///
/// **Présentation, pas navigation** : seule l'application existe aujourd'hui.
/// Rendre ces vignettes cliquables promettrait des écrans qui n'existent pas ;
/// elles annoncent une ambition, elles ne simulent pas une fonctionnalité.
class BrandPillars extends StatelessWidget {
  const BrandPillars({super.key});

  static const double _gap = AppSpacing.xs;

  static const List<(IconData, String)> _pillars = [
    (AppIcons.brandApp, 'APP'),
    (AppIcons.brandAcademy, 'ACADEMY'),
    (AppIcons.brandEvents, 'EVENTS'),
    (AppIcons.brandWear, 'WEAR'),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Les univers Carlys : application, academy, events, wear',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, pillar) in _pillars.indexed) ...[
                if (index > 0) const SizedBox(width: _gap),
                Expanded(
                  child: _Pillar(icon: pillar.$1, name: pillar.$2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.icon, required this.name});

  final IconData icon;
  final String name;

  static const double _iconSize = 26;
  static const double _labelSize = 9;

  @override
  Widget build(BuildContext context) {
    final label = AppTypography.labelMono.copyWith(fontSize: _labelSize);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.statTileAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize, color: AppColors.darkTextSecondary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'CARLYS',
            textAlign: TextAlign.center,
            style: label.copyWith(color: AppColors.darkTextTertiary),
          ),
          const SizedBox(height: AppSpacing.xxs / 2),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: label.copyWith(color: AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}
