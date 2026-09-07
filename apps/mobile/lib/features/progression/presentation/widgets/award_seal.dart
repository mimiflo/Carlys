import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import 'seal_painter.dart';
import 'seal_size.dart';

/// LE SCEAU : une SILHOUETTE, pas une pastille colorée.
///
/// C'est la forme qui porte le sens — écu, disque à ruban, feuille cachetée,
/// plaque, cartouche. La version précédente distinguait les récompenses par
/// leur teinte de remplissage : cinq ronds identiques, qu'on ne pouvait pas
/// nommer sans lire la légende.
///
/// Construction constante, quelle que soit la forme : la silhouette est
/// remplie du dégradé, puis LA MÊME silhouette, insérée de deux pixels, est
/// remplie de la surface. Le filet naît de la différence, comme sur un sceau
/// frappé — jamais d'un trait dessiné par-dessus.
///
/// Deux tailles seulement, décrites par [SealSize] : le peintre s'y règle
/// comme le widget, aucun des deux ne détient les chiffres de l'autre.
class AwardSeal extends StatelessWidget {
  const AwardSeal({
    required this.kind,
    this.size = SealSize.large,
    this.figure,
    this.earned = true,
    super.key,
  });

  final RewardKind kind;
  final double size;

  /// Ce qui est frappé au centre : « 80 » pour un record, « IV » pour un
  /// titre. Les autres formes portent un glyphe.
  final String? figure;

  /// Pas encore gagné : la silhouette est là, elle n'est pas frappée.
  final bool earned;

  bool get _isLarge => SealSize.isLarge(size);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: SealPainter(kind: kind, size: size, earned: earned),
        child: Center(child: _mark()),
      ),
    );
  }

  Widget _mark() {
    final text = figure;
    if (text != null) {
      return Text(
        text,
        style: (_isLarge ? AppTypography.metricS : AppTypography.labelMono)
            .copyWith(
              fontSize: _isLarge ? (kind == RewardKind.titre ? 16 : 15) : 11,
              color: AppColors.primaryLight,
            ),
      );
    }
    // Le certificat ne porte AUCUNE marque : ses filets de texte et son
    // cachet disent déjà ce qu'il est.
    if (kind == RewardKind.certificat) return const SizedBox.shrink();
    return Icon(
      _glyph(kind),
      size: _isLarge ? 22 : 15,
      color: AppColors.primaryLight,
    );
  }

  static IconData _glyph(RewardKind kind) => switch (kind) {
    RewardKind.badge => AppIcons.brandAcademy,
    RewardKind.medaille => AppIcons.medal,
    RewardKind.certificat => AppIcons.certificate,
    RewardKind.record => AppIcons.record,
    RewardKind.titre => AppIcons.crown,
  };
}
