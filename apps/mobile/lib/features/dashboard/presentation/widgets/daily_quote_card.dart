import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/daily_quote.dart';

/// LA CITATION DU JOUR, sans carte.
///
/// Un cadre autour d'une phrase en faisait une rubrique de plus, à moitié
/// vide les jours où la maxime est courte. Un simple filet vertical suffit à
/// dire « ceci est une citation » — c'est la marque du bloc cité, vieille
/// comme la typographie, et elle ne creuse jamais.
///
/// La valeur Carlys qu'elle sert n'est PAS affichée : elle ordonne la
/// rotation en coulisses, l'écran n'a rien à en dire.
class DailyQuoteCard extends StatelessWidget {
  const DailyQuoteCard({required this.quote, super.key});

  final DailyQuote quote;

  /// La phrase s'adapte à la place reçue : les maximes vont du simple au
  /// double en longueur, et un corps fixe déborderait un jour sur deux.
  static const double _minSize = 15;
  static const double _maxSize = 21;
  static const double _lineHeight = 1.16;

  /// Corps et écart du libellé « CITATION DU JOUR ».
  static const double _labelSize = 9;
  static const double _labelGap = AppSpacing.sm;

  /// Le plus petit cadre où la maxime s'écrit encore sur DEUX lignes à son
  /// corps minimal, libellé compris, pour une échelle de texte donnée. La
  /// zone haute ne descend pas en dessous : en texte agrandi, elle s'allonge
  /// plutôt que de laisser la maxime déborder.
  static double minHeightFor(TextScaler scaler) =>
      2 * scaler.scale(_minSize) * _lineHeight +
      _labelGap +
      scaler.scale(_labelSize) * AppTypography.labelMono.height!;

  /// Épaisseur et retrait du filet de citation.
  static const double _rule = 1;
  static const double _inset = AppSpacing.gapRow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Citation du jour, ${quote.value.label} : ${quote.text}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              width: _rule,
              child: ColoredBox(color: AppColors.majestyBorder),
            ),
            const SizedBox(width: _inset),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: AppFittedText(
                      quote.text,
                      minFontSize: _minSize,
                      maxFontSize: _maxSize,
                      style: AppTypography.quote.copyWith(
                        fontWeight: FontWeight.w500,
                        height: _lineHeight,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: _labelGap),
                  // Une ligne, toujours : en texte agrandi, le libellé passé
                  // sur deux lignes prenait sa place à la maxime.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CITATION DU JOUR',
                      maxLines: 1,
                      style:
                          AppTypography.resized(
                            AppTypography.labelMono,
                            _labelSize,
                          ).copyWith(
                            letterSpacing: 1.4,
                            color: AppColors.darkTextTertiary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
