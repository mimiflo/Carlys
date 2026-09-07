/// Abonnement de la DÉMONSTRATION (flavor `demo`) — aucun réseau, aucun
/// paiement : le catalogue se visite, l'achat est refusé comme il le serait
/// par le serveur.
library;

import '../core/errors/app_exception.dart';
import '../features/subscription/domain/entities/subscription.dart';
import '../features/subscription/domain/repositories/subscription_repository.dart';

/// Plan Premium actif : tous les contenus sont visitables.
class DemoSubscriptionRepository implements SubscriptionRepository {
  @override
  Future<PlanStatus> planStatus() async => PlanStatus(
    planName: 'Premium (démo)',
    isPremium: true,
    subscription: SubscriptionInfo(
      planName: 'Premium (démo)',
      state: SubscriptionState.active,
      cancelAtPeriodEnd: false,
      currentPeriodEnd: DateTime.utc(2026, 9, 7),
    ),
  );

  @override
  Future<List<EntitlementEntry>> entitlements() async => const [
    EntitlementEntry(key: 'unlimited_programs', isActive: true),
    EntitlementEntry(key: 'advanced_statistics', isActive: true),
    EntitlementEntry(key: 'premium_exercises', isActive: true),
    EntitlementEntry(key: 'cloud_backup', isActive: true),
    EntitlementEntry(key: 'priority_support', isActive: true),
  ];

  /// Le catalogue est visitable en démonstration ; l'achat, non. Ouvrir une
  /// vraie page de paiement depuis une démonstration serait un piège.
  @override
  Future<OfferCatalog> offers() async => const OfferCatalog(
    checkoutAvailable: false,
    offers: [
      SubscriptionOffer(
        id: 'premium-mensuel',
        name: 'Premium mensuel',
        period: OfferPeriod.month,
        amountCents: 999,
        currency: 'EUR',
        monthlyEquivalentCents: 999,
        trialDays: 7,
        isRecommended: false,
      ),
      SubscriptionOffer(
        id: 'premium-annuel',
        name: 'Premium annuel',
        period: OfferPeriod.year,
        amountCents: 7990,
        currency: 'EUR',
        monthlyEquivalentCents: 666,
        trialDays: 7,
        isRecommended: true,
        savingPercent: 33,
      ),
    ],
  );

  @override
  Future<String> startCheckout({
    required String offerId,
    required String id,
  }) async {
    throw StateError('Le paiement n’existe pas en démonstration.');
  }

  /// Le plan de démonstration est Premium, la ligne « Gérer mon
  /// abonnement » est donc là ; mais aucun client de facturation n'existe
  /// derrière. Le dépôt refuse comme le ferait le serveur, avec le message
  /// que l'écran affiche sous la ligne.
  @override
  Future<String> startBillingPortal() async {
    throw const ForbiddenException(
      'Le portail de facturation n’existe pas en démonstration.',
    );
  }
}
