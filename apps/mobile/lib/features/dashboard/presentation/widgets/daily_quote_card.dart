import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/daily_quote.dart';

/// Citation du jour, en carte compacte posée **à gauche du cœur**.
///
/// La valeur Carlys qu'elle sert n'est PAS affichée — elle ordonne la
/// rotation en coulisses (une valeur différente chaque jour), mais l'écran
/// n'a rien à en dire.
class DailyQuoteCard extends StatelessWidget {
  const DailyQuoteCard({required this.quote, super.key});

  final DailyQuote quote;

  /// Géométrie COMPACTE : la carte vit à gauche du cœur, sur un peu plus
  /// d'une demi-largeur. Phrase en 15/1.38, glyphe décoratif de 28.
  static const double _quoteSize = 15;
  static const double _quoteHeight = 1.38;
  static const double _glyphSize = 28;

  /// Interligne ÉCRASÉ du glyphe : sans lui, sa boîte de ligne de 38 pousse
  /// toute la ligne du label vers le bas et creuse un trou dans la carte.
  /// L'encre déborde de la boîte, ce qui est exactement l'effet voulu.
  static const double _glyphLineHeight = 0.42;

  @override
  Widget build(BuildContext context) {
    return AppLabeledCard(
      label: 'Citation du jour',
      padding: const EdgeInsets.all(AppSpacing.sm),
      semanticLabel: 'Citation du jour, ${quote.value.label} : ${quote.text}',
      trailing: Text(
        '”',
        style: AppTypography.display.copyWith(
          fontSize: _glyphSize,
          height: _glyphLineHeight,
          color: AppColors.primaryLight,
        ),
      ),
      child: Text(
        quote.text,
        style: AppTypography.title.copyWith(
          fontSize: _quoteSize,
          height: _quoteHeight,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
      ),
    );
  }
}
