import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';

/// Profil incomplet : liste des champs que le serveur attend encore pour
/// calculer le métabolisme (aucun calcul n'est fait côté client).
class MissingProfileCard extends StatelessWidget {
  const MissingProfileCard({required this.missing, super.key});

  final List<MetabolismMissingField> missing;

  /// Puce de la ligne — géométrie pure, teinte du design system.
  static const double _bulletSize = 5;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < missing.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == missing.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: _bulletSize,
                    height: _bulletSize,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      missing[index].label,
                      style: AppTypography.label
                          .copyWith(color: AppColors.darkTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
