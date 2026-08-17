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
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'CITATION DU JOUR',
                    style: AppTypography.labelMono.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.4,
                      color: AppColors.darkTextTertiary,
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
