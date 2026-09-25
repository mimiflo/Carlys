import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';

/// UN aliment sur une rangée : la vignette de sa famille (la table n'a pas
/// de photos), son nom court et son nom officiel, puis ce que la rangée en
/// dit à droite ([trailing]) — ses calories pour 100 g dans la recherche, sa
/// quantité et la croix qui la retire dans un repas.
///
/// La mise en page est UNE, pour les deux rangées : un réglage (le seuil,
/// les styles des noms) ne peut plus diverger de l'une à l'autre.
class FoodIdentityRow extends StatelessWidget {
  const FoodIdentityRow({
    required this.icon,
    required this.shortName,
    required this.name,
    required this.trailing,
    super.key,
  });

  /// L'icône de la famille de l'aliment.
  final IconData icon;

  /// « Poulet »…
  final String shortName;

  /// … et « Poulet, filet, sans peau, cuit », le nom officiel de la table.
  final String name;
  final Widget trailing;

  /// En dessous de cette largeur (en points de texte, donc agrandie avec
  /// lui), [trailing] passe SOUS les noms : sur 320 points en grand texte, la
  /// rangée ne logerait plus le nom de l'aliment.
  static const double _wideRow = 280;

  @override
  Widget build(BuildContext context) {
    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shortName,
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          name,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
            height: AppTypography.body.height,
          ),
        ),
      ],
    );
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= textScaler.scale(_wideRow);
        final identity = Row(
          children: [
            AppIconDisc(icon: icon),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: names),
            if (wide) ...[const SizedBox(width: AppSpacing.xs), trailing],
          ],
        );
        if (wide) {
          return identity;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [identity, trailing],
        );
      },
    );
  }
}
