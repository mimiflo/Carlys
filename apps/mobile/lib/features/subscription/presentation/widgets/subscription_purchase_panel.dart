import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/subscription.dart';
import '../controllers/subscription_controllers.dart';
import 'subscription_offers.dart';

/// Le bloc d'achat : les offres, puis le bouton qui ouvre le paiement.
///
/// Il DIT la vérité dans les deux sens. Tant que le paiement n'est pas ouvert
/// côté serveur, il montre le catalogue sans bouton : afficher un achat qui
/// échouerait serait pire que de ne rien afficher. Et le droit n'est jamais
/// accordé ici : la page de paiement s'ouvre dehors, l'argent est encaissé
/// par le prestataire, et le serveur accorde Premium sur webhook signé.
class SubscriptionPurchasePanel extends ConsumerStatefulWidget {
  const SubscriptionPurchasePanel({super.key});

  @override
  ConsumerState<SubscriptionPurchasePanel> createState() =>
      _SubscriptionPurchasePanelState();
}

class _SubscriptionPurchasePanelState
    extends ConsumerState<SubscriptionPurchasePanel> {
  String? _selectedId;
  bool _opening = false;

  Future<void> _buy(SubscriptionOffer offer) async {
    setState(() => _opening = true);
    final outcome = await ref.read(subscriptionActionsProvider).buy(offer);
    if (!mounted) return;
    setState(() => _opening = false);

    final message = switch (outcome) {
      CheckoutOutcome.opened => null,
      CheckoutOutcome.unavailable =>
        'Le paiement n’est pas encore ouvert. Réessaie bientôt.',
      CheckoutOutcome.cannotOpen =>
        'Aucun navigateur n’a pu s’ouvrir sur cet appareil.',
      CheckoutOutcome.failed => 'La page de paiement n’a pas pu s’ouvrir.',
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(offerCatalogProvider);

    return catalog.when(
      // Le catalogue n'est pas le cœur de l'écran : son chargement ne doit
      // pas faire clignoter une page qui a déjà tout dit de Premium.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.offers.isEmpty) return const SizedBox.shrink();
        final selected = _resolveSelection(data);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SubscriptionOffers(
              catalog: data,
              selectedId: selected.id,
              onSelect: (offer) => setState(() => _selectedId = offer.id),
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.checkoutAvailable)
              AppButton(
                label: 'Passer à Premium',
                onPressed: _opening ? null : () => _buy(selected),
                isLoading: _opening,
                isExpanded: true,
              )
            else
              Text(
                'L’achat depuis l’application arrive bientôt. Les prix '
                'ci-dessus sont ceux qui s’appliqueront.',
                textAlign: TextAlign.center,
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
          ],
        );
      },
    );
  }

  /// L'offre retenue : celle qu'on a touchée, sinon celle que le SERVEUR
  /// recommande. Le choix par défaut n'est pas décidé par l'application.
  SubscriptionOffer _resolveSelection(OfferCatalog catalog) {
    final chosen = _selectedId;
    if (chosen != null) {
      for (final offer in catalog.offers) {
        if (offer.id == chosen) return offer;
      }
    }
    return catalog.offers.firstWhere(
      (offer) => offer.isRecommended,
      orElse: () => catalog.offers.first,
    );
  }
}
