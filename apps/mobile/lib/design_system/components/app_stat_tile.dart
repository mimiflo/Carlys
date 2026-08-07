import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../typography/app_typography.dart';
import 'app_gauge.dart';

/// Tuile de stat de la refonte : label mono → valeur mono → jauge 3px.
/// S'utilise en grille de 3, gap 10.
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    required this.label,
    required this.value,
    this.unit,
    this.progress,
    this.gaugeColor = AppColors.primary,
    super.key,
  });

  /// Label court, affiché en MAJUSCULES mono (ex. « KCAL »).
  final String label;
  final String value;

  /// Unité collée à la valeur (ex. « g », « h »), en 12px tertiaire.
  final String? unit;

  /// Progression 0..1 de la jauge — absente si null.
  final double? progress;
  final Color gaugeColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : $value${unit ?? ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.statTileAll,
          border:
              Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMono
                  .copyWith(fontSize: 9, color: AppColors.darkTextTertiary),
            ),
            const SizedBox(height: 7),
            Text.rich(
              TextSpan(
                text: value,
                style: AppTypography.metricM
                    .copyWith(color: AppColors.darkTextPrimary),
                children: [
                  if (unit != null)
                    TextSpan(
                      text: unit,
                      style: AppTypography.label
                          .copyWith(color: AppColors.darkTextTertiary),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (progress != null) ...[
              const SizedBox(height: 7),
              AppGauge(progress: progress!, color: gaugeColor, height: 3),
            ],
          ],
        ),
      ),
    );
  }
}
