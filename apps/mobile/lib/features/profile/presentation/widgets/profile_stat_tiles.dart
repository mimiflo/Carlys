import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Grille de tuiles mono du profil : poids, taille, séances.
///
/// Une tuile dont la donnée n'est pas encore servie est simplement absente —
/// aucune valeur de remplacement n'est affichée.
class ProfileStatTiles extends StatelessWidget {
  const ProfileStatTiles({
    required this.weightKg,
    required this.heightCm,
    required this.sessionsCount,
    super.key,
  });

  /// Dernière mesure corporelle de poids.
  final double? weightKg;

  /// Taille du profil métabolique.
  final double? heightCm;

  /// Séances enregistrées sur les douze derniers mois.
  final int? sessionsCount;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (weightKg != null)
        AppStatTile(
          label: 'Poids',
          value: formatDecimal(weightKg!),
          unit: 'kg',
        ),
      if (heightCm != null)
        AppStatTile(
          label: 'Taille',
          value: formatDecimal(heightCm!),
          unit: 'cm',
        ),
      if (sessionsCount != null)
        AppStatTile(
          label: 'Séances',
          value: formatThousands(sessionsCount!),
        ),
    ];

    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, tile) in tiles.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.gapTile),
          Expanded(child: tile),
        ],
      ],
    );
  }
}
