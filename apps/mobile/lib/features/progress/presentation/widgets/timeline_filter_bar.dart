import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

/// Les filtres de la frise : tout, ou une famille à la fois.
///
/// Une frise de deux ans sans filtre est illisible — huit cents lignes où
/// l'on cherche un record. Trois choix plutôt que six : on cherche « mes
/// records », « mes séances » ou « mes franchissements », rarement « mes
/// pesées seules ».
class TimelineFilterBar extends StatelessWidget {
  const TimelineFilterBar({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// Vide = tout. Le serveur lit la liste vide comme « aucun filtre ».
  final List<ProgressEventKind> selected;
  final ValueChanged<List<ProgressEventKind>> onChanged;

  /// Les familles offertes, et ce qu'elles retiennent.
  static const List<(String, List<ProgressEventKind>)> families = [
    ('Tout', <ProgressEventKind>[]),
    ('Séances', [ProgressEventKind.session]),
    (
      'Franchissements',
      [
        ProgressEventKind.record,
        ProgressEventKind.reward,
        ProgressEventKind.title,
      ],
    ),
    ('Mesures', [ProgressEventKind.measure]),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.touchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: families.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final (label, kinds) = families[index];
          final actif = _memeFamille(kinds, selected);
          return Center(
            child: _Puce(
              label: label,
              active: actif,
              // Retaper le filtre actif ne le retire pas : « Tout » est
              // toujours à un geste, et un écran vide par accident ne
              // ressemble à rien.
              onTap: actif ? null : () => onChanged(kinds),
            ),
          );
        },
      ),
    );
  }

  static bool _memeFamille(
    List<ProgressEventKind> a,
    List<ProgressEventKind> b,
  ) => a.length == b.length && a.every(b.contains);
}

class _Puce extends StatelessWidget {
  const _Puce({required this.label, required this.active, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryBadgeBg : AppColors.darkSurface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active
                  ? AppColors.primaryBadgeBorder
                  : AppColors.darkBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: active
                  ? AppColors.primaryLight
                  : AppColors.darkTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
