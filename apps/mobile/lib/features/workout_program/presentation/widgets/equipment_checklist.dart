import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../exercises/domain/entities/exercise.dart';
import '../../../exercises/presentation/utils/equipment_categories.dart';
import 'equipment_check_row.dart';

/// Le matériel, rangé par FAMILLE : une carte repliée par famille dit ce qui
/// y est coché ; dépliée, elle se coche d'un geste (« Tout cocher ») ou
/// ligne à ligne. Chaque geste se voit d'avance, puis écrit la liste
/// COMPLÈTE.
class EquipmentChecklist extends StatefulWidget {
  const EquipmentChecklist({
    required this.catalog,
    required this.ownedSlugs,
    required this.onToggle,
    required this.onSetGroup,
    super.key,
  });

  final List<EquipmentRef> catalog;
  final Set<String> ownedSlugs;
  final ValueChanged<EquipmentRef> onToggle;

  /// Coche ([owned] vrai) ou décoche toute une famille d'un geste.
  final void Function(List<EquipmentRef> group, {required bool owned})
  onSetGroup;

  @override
  State<EquipmentChecklist> createState() => _EquipmentChecklistState();
}

class _EquipmentChecklistState extends State<EquipmentChecklist> {
  final Set<EquipmentCategory> _open = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, (category, items)) in groupEquipment(
          widget.catalog,
        ).indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xs),
          _CategoryCard(
            category: category,
            items: items,
            owned: widget.ownedSlugs,
            open: _open.contains(category),
            onOpen: () => setState(() {
              if (!_open.remove(category)) _open.add(category);
            }),
            onToggle: widget.onToggle,
            onSetGroup: (owned) => widget.onSetGroup(items, owned: owned),
          ),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.items,
    required this.owned,
    required this.open,
    required this.onOpen,
    required this.onToggle,
    required this.onSetGroup,
  });

  final EquipmentCategory category;
  final List<EquipmentRef> items;
  final Set<String> owned;
  final bool open;
  final VoidCallback onOpen;
  final ValueChanged<EquipmentRef> onToggle;
  final ValueChanged<bool> onSetGroup;

  @override
  Widget build(BuildContext context) {
    final chosen = [
      for (final item in items)
        if (owned.contains(item.slug)) item.name,
    ];
    final all = chosen.length == items.length;
    final count = '${chosen.length} sur ${items.length}';
    // Le compte sous le titre, pas à sa droite : en texte agrandi, la
    // rangée n'a plus la place d'une colonne de plus.
    final summary = chosen.isEmpty
        ? 'Rien de coché'
        : '$count · ${chosen.join(', ')}';
    final spoken = chosen.isEmpty
        ? summary
        : '$count cochés : ${chosen.join(', ')}';

    return Material(
      color: AppColors.darkSurfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardSecondaryAll,
        side: BorderSide(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: '${category.label}, $spoken',
            onTap: onOpen,
            excludeSemantics: true,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    AppIconBadge(
                      icon: category.icon,
                      size: 40,
                      color: AppColors.primaryLight,
                      background: AppColors.primaryBadgeBg,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.label,
                            style: AppTypography.subheading.copyWith(
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              color: chosen.isEmpty
                                  ? AppColors.darkTextTertiary
                                  : AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      open ? AppIcons.collapse : AppIcons.expand,
                      color: AppColors.primaryLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open) ...[
            EquipmentCheckRow(
              label: all ? 'Tout décocher' : 'Tout cocher',
              semantics: all
                  ? 'Tout décocher : ${category.label}'
                  : 'Tout cocher : ${category.label}',
              checked: all,
              strong: true,
              onTap: () => onSetGroup(!all),
            ),
            for (final item in items)
              EquipmentCheckRow(
                label: item.name,
                semantics:
                    '${item.name}'
                    '${owned.contains(item.slug) ? ', disponible' : ''}',
                icon: equipmentIcon(item.slug),
                checked: owned.contains(item.slug),
                onTap: () => onToggle(item),
              ),
          ],
        ],
      ),
    );
  }
}
