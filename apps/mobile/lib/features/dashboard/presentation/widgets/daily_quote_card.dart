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

  /// La phrase **s'adapte à la carte** : elle grossit quand elle est courte,
  /// se resserre quand elle est longue, et remplit toujours la place reçue.
  /// Les maximes vont du simple au double en longueur — sans cela, le cadre
  /// paraîtrait creux un jour et déborderait le lendemain.
  static const double _quoteMinSize = 14;
  static const double _quoteMaxSize = 30;
  static const double _quoteHeight = 1.22;
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
      // La hauteur vient de la zone haute : le texte reçoit tout l'espace
      // sous le label, et s'y ajuste.
      expandChild: true,
      semanticLabel: 'Citation du jour, ${quote.value.label} : ${quote.text}',
      trailing: Text(
        '”',
        style: AppTypography.display.copyWith(
          fontSize: _glyphSize,
          height: _glyphLineHeight,
          color: AppColors.primaryLight,
        ),
      ),
      child: AppFittedText(
        quote.text,
        minFontSize: _quoteMinSize,
        maxFontSize: _quoteMaxSize,
        style: AppTypography.quote.copyWith(
          height: _quoteHeight,
          color: AppColors.darkTextPrimary,
        ),
      ),
    );
  }
}
