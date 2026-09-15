import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../radius/app_radius.dart';
import '../typography/app_typography.dart';
import 'app_explain_button.dart';
import 'app_explainable.dart';
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
    this.onExplain,
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

  /// Ouvre le POURQUOI de la donnée.
  ///
  /// Quand il est fourni, la tuile porte le glyphe d'explication À CÔTÉ de
  /// son label et devient elle-même la cible tactile — voir [AppExplainable]
  /// pour l'arbitrage.
  final VoidCallback? onExplain;

  static const BoxDecoration _pleine = BoxDecoration(
    color: AppColors.darkSurface,
    borderRadius: AppRadius.statTileAll,
    border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
  );

  /// Même tuile sans son fond : c'est le `Material` d'[AppExplainable] qui le
  /// peint, sinon l'onde se noierait derrière une surface opaque.
  static const BoxDecoration _bordSeul = BoxDecoration(
    borderRadius: AppRadius.statTileAll,
    border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
  );

  @override
  Widget build(BuildContext context) {
    final corps = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.resized(
                    AppTypography.labelMono,
                    9,
                  ).copyWith(color: AppColors.darkTextTertiary),
                ),
              ),
              if (onExplain != null)
                const Icon(
                  AppIcons.info,
                  size: AppExplainButton.glyphSize,
                  color: AppColors.darkTextTertiary,
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text.rich(
            TextSpan(
              text: value,
              style: AppTypography.metricM.copyWith(
                color: AppColors.darkTextPrimary,
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextTertiary,
                    ),
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
    );

    final enonce = '$label : $value${unit ?? ''}';
    final ouvrir = onExplain;

    if (ouvrir == null) {
      return Semantics(
        label: enonce,
        child: DecoratedBox(decoration: _pleine, child: corps),
      );
    }

    return AppExplainable(
      enonce: enonce,
      onExplain: ouvrir,
      surface: AppColors.darkSurface,
      borderRadius: AppRadius.statTileAll,
      child: DecoratedBox(decoration: _bordSeul, child: corps),
    );
  }
}
