import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

// Grammaire de la carte maîtresse de Progrès, relevée sur la maquette et
// partagée avec la carte de volume (volume_card.dart) : padding 20, libellé
// à 6 de sa valeur, valeur mono à 30 resserrée, unité à 15. Nommées ICI
// plutôt qu'écrites dans les widgets ; si un troisième usage apparaît,
// elles montent en tokens.
const EdgeInsets _cardPadding = EdgeInsets.all(20);
const double _labelGap = 6;
const double _valueFontSize = 30;
const double _valueLetterSpacing = -1.2;
const double _unitFontSize = 15;

/// Carte de tête de la section poids : la même surface sous la courbe et
/// sous la première mesure, pour que l'arrivée de la courbe ne change pas
/// le décor.
class BodyWeightCard extends StatelessWidget {
  const BodyWeightCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _cardPadding,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardMainAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: child,
    );
  }
}

/// « Dernière mesure » en grand : un fait, lisible seul.
class BodyWeightLatest extends StatelessWidget {
  const BodyWeightLatest({required this.entry, super.key});

  final BodyMetricEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionLabel(
          'Dernière mesure',
          color: AppColors.darkTextTertiary,
        ),
        const SizedBox(height: _labelGap),
        Text.rich(
          TextSpan(
            text: formatDecimal(entry.value),
            style: AppTypography.metricL.copyWith(
              fontSize: _valueFontSize,
              letterSpacing: _valueLetterSpacing,
              color: AppColors.darkTextPrimary,
            ),
            children: [
              TextSpan(
                text: ' kg',
                style: AppTypography.metricS.copyWith(
                  fontSize: _unitFontSize,
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// UNE mesure : la valeur comme un fait, et ce qu'il manque pour la courbe.
///
/// Avec un seul point, un graphique ne trace rien : la carte affichait un
/// rectangle vide de 104 points sous un balayage qui n'animait aucun tracé,
/// et une date orpheline. Après le geste que l'écran vient d'inviter, on
/// reçoit un fait et une promesse tenue, pas un grand vide.
class BodyWeightFirstMeasure extends StatelessWidget {
  const BodyWeightFirstMeasure({required this.entry, super.key});

  final BodyMetricEntry entry;

  /// Ce que la carte annonce : une mesure de plus et la courbe apparaît.
  static const String note = 'Une mesure de plus et la courbe apparaît.';

  @override
  Widget build(BuildContext context) {
    return BodyWeightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyWeightLatest(entry: entry),
          const SizedBox(height: AppSpacing.md),
          Text(
            note,
            style: AppTypography.label.copyWith(color: AppColors.primaryLight),
          ),
        ],
      ),
    );
  }
}
