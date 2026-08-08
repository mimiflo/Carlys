import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/daily_quote.dart';

/// Maxime du jour, sous le cœur : la valeur Carlys en label mono, puis la
/// phrase en grand.
///
/// Elle occupe la place que tenait l'indice de forme : c'est la première
/// chose qu'on lit en ouvrant l'application, donc elle doit motiver, pas
/// mesurer. Le chiffre, lui, est descendu près de « Ta semaine ».
class DailyQuoteBlock extends StatelessWidget {
  const DailyQuoteBlock({required this.quote, super.key});

  final DailyQuote quote;

  /// Géométrie : phrase en 21/1.32, assez grande pour porter seule la zone
  /// haute sans concurrencer le titre d'accueil.
  static const double _quoteSize = 21;
  static const double _quoteHeight = 1.32;

  /// Filet accent à gauche, comme une citation.
  static const double _railWidth = 2;
  static const double _railGap = AppSpacing.gapTile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Maxime du jour, ${quote.value.label} : ${quote.text}',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: _railWidth,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: AppRadius.fullAll,
                ),
              ),
              const SizedBox(width: _railGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSectionLabel(quote.value.label),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      quote.text,
                      style: AppTypography.title.copyWith(
                        fontSize: _quoteSize,
                        height: _quoteHeight,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
