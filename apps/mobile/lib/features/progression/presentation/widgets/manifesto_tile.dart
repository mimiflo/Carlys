import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// LE RENVOI AU MANIFESTE.
///
/// Les points disent OÙ tu en es ; le manifeste dit POURQUOI ces cinq
/// axes-là. La tuile ferme l'écran sur la question plutôt que sur un score,
/// et c'est le seul endroit du profil où la marque parle d'elle-même.
///
/// Une flèche, pas un chevron : on part lire ailleurs, on ne déplie pas.
class ManifestoTile extends StatelessWidget {
  const ManifestoTile({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Le manifeste Carlys',
      onTap: onOpen,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onOpen,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.manifestoTile,
              borderRadius: BorderRadius.circular(AppRadius.cardSecondary),
              border: Border.all(color: AppColors.majestyBorder),
            ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.padCard),
              child: Row(
                children: [
                  Expanded(child: _Wording()),
                  SizedBox(width: AppSpacing.gapRow),
                  Icon(
                    AppIcons.arrowForward,
                    size: 20,
                    color: AppColors.primaryLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wording extends StatelessWidget {
  const _Wording();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le manifeste Carlys',
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Pourquoi essayer compte plus que réussir.',
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}
