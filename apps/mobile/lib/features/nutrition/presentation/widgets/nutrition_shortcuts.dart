import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import 'scanned_product_sheet.dart';

/// Les quatre gestes de la page, en tuiles, ceux de la maquette : ajouter un
/// repas (le geste premier, mis en avant), scanner un produit emballé,
/// ouvrir les recettes, comprendre ses objectifs. L'eau se note depuis
/// l'accueil (cellule Hydratation). Chacun mène à ce qui existe — jamais une tuile vide.
class NutritionShortcuts extends StatelessWidget {
  const NutritionShortcuts({required this.day, super.key});

  /// Le jour affiché : un repas ajouté d'ici est daté de ce jour.
  final DateTime day;

  static const double _tileWidth = 72;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveGrid(
      minItemWidth: _tileWidth,
      children: [
        _ShortcutTile(
          icon: AppIcons.add,
          label: 'Ajouter un repas',
          primary: true,
          onTap: () => context.push(AppRoutes.newMeal(day: day)),
        ),
        _ShortcutTile(
          icon: AppIcons.scanBarcode,
          label: 'Scanner un aliment',
          onTap: () => scanFood(context, day),
        ),
        _ShortcutTile(
          icon: AppIcons.recipes,
          label: 'Mes recettes',
          onTap: () => context.push(AppRoutes.recipes),
        ),
        _ShortcutTile(
          icon: AppIcons.metabolism,
          label: 'Mes besoins',
          onTap: () => context.push(AppRoutes.metabolism),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Le geste premier : son icône dans une pastille au dégradé violet.
  final bool primary;

  static const double _badge = 40;

  @override
  Widget build(BuildContext context) {
    final glyph = primary
        ? Container(
            width: _badge,
            height: _badge,
            decoration: const BoxDecoration(
              gradient: AppColors.cta,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.darkTextPrimary),
          )
        : SizedBox.square(
            dimension: _badge,
            child: Icon(icon, color: AppColors.primaryLight),
          );
    return AppCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          glyph,
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(
              color: primary
                  ? AppColors.darkTextPrimary
                  : AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
