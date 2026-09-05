import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/subscription.dart';

/// Formate un montant en centimes avec sa devise.
///
/// Deux décimales seulement quand elles existent : « 9,99 € » se lit, mais
/// « 80,00 € » alourdit une comparaison de prix pour ne rien dire de plus.
String formatOfferPrice(int amountCents, String currency) {
  final symbol = currency == 'EUR' ? '€' : currency;
  final units = amountCents ~/ 100;
  final cents = amountCents % 100;
  final amount = cents == 0
      ? '$units'
      : '$units,${cents.toString().padLeft(2, '0')}';
  return '$amount $symbol';
}

/// Les cartes d'offre : le prix, le rythme, et ce que l'annuel fait gagner.
///
/// Les prix viennent du serveur. Rien ici n'est écrit en dur : un tarif
/// codé dans l'application deviendrait faux le jour où il change, et il
/// faudrait publier une mise à jour pour corriger un prix.
class SubscriptionOffers extends StatelessWidget {
  const SubscriptionOffers({
    required this.catalog,
    required this.selectedId,
    required this.onSelect,
    super.key,
  });

  final OfferCatalog catalog;
  final String? selectedId;
  final ValueChanged<SubscriptionOffer> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final offer in catalog.offers) ...[
          _OfferCard(
            offer: offer,
            isSelected: offer.id == selectedId,
            onTap: () => onSelect(offer),
          ),
          if (offer != catalog.offers.last)
            const SizedBox(height: AppSpacing.gapRow),
        ],
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.isSelected,
    required this.onTap,
  });

  final SubscriptionOffer offer;
  final bool isSelected;
  final VoidCallback onTap;

  static const EdgeInsets _padding = EdgeInsets.all(
    AppSpacing.md + AppSpacing.xxs,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${offer.name}, ${formatOfferPrice(offer.amountCents, offer.currency)} '
          '${offer.period.suffix}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.darkBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: _padding,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                offer.name,
                                style: AppTypography.subheading.copyWith(
                                  color: AppColors.darkTextPrimary,
                                ),
                              ),
                            ),
                            if (offer.savingPercent case final saving?) ...[
                              const SizedBox(width: AppSpacing.xs),
                              AppPill(
                                label: '−$saving %',
                                tone: AppPillTone.accent,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _detail(offer),
                          style: AppTypography.label.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapRow),
                  Text(
                    formatOfferPrice(offer.amountCents, offer.currency),
                    style: AppTypography.title.copyWith(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.darkTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sous l'annuel, le prix ramené au mois : c'est la seule comparaison
  /// honnête entre deux rythmes, et elle évite un calcul mental.
  static String _detail(SubscriptionOffer offer) {
    if (offer.period == OfferPeriod.year) {
      final monthly = formatOfferPrice(
        offer.monthlyEquivalentCents,
        offer.currency,
      );
      return 'Soit $monthly par mois';
    }
    if (offer.trialDays > 0) {
      return '${offer.trialDays} jours d’essai, puis ${offer.period.suffix}';
    }
    return 'Facturé ${offer.period.suffix}';
  }
}
