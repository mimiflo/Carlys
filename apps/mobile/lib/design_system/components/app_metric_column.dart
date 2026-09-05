import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../typography/app_typography.dart';

/// Colonne label + valeur des cartes de séance (« VOLUME / 5,2 t »).
/// Se pose en rangée, gap 18, sans fond ni bordure.
class AppMetricColumn extends StatelessWidget {
  const AppMetricColumn({
    required this.label,
    required this.value,
    this.unit,
    super.key,
  });

  final String label;
  final String value;

  /// Unité collée à la valeur, en plus petit (« t », « kg »).
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : $value${unit ?? ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelMono.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              color: AppColors.darkTextTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: value,
              style: AppTypography.metricS.copyWith(
                fontSize: 14,
                color: AppColors.darkTextPrimary,
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: AppTypography.metricS.copyWith(
                      fontSize: 14,
                      color: AppColors.darkTextPrimary,
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
