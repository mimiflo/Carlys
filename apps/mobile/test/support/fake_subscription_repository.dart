import 'dart:async';

import 'package:carlys_mobile/features/subscription/domain/entities/subscription.dart';
import 'package:carlys_mobile/features/subscription/domain/repositories/subscription_repository.dart';

/// SubscriptionRepository de test — état en mémoire, aucune requête réseau.
class FakeSubscriptionRepository implements SubscriptionRepository {
  FakeSubscriptionRepository({
    this.isPremium = false,
    this.checkoutAvailable = false,
    this.checkoutUrl = 'https://paiement.exemple/session',
    this.checkoutError,
    this.portalUrl = 'https://portail.exemple/session',
    this.portalError,
  });

  /// Mutable : un test simule le webhook qui accorde Premium PENDANT que
  /// l'utilisateur est parti payer, puis vérifie que le retour le relit.
  bool isPremium;

  /// Le serveur ouvre-t-il un paiement ? C'est LUI qui décide, l'écran suit.
  final bool checkoutAvailable;
  final String checkoutUrl;
  final Object? checkoutError;

  /// Les demandes de paiement reçues, dans l'ordre : identifiant d'offre et
  /// identifiant d'appareil.
  final List<({String offerId, String id})> checkouts = [];

  /// Combien de fois le plan a été lu : c'est ce qui prouve qu'un retour
  /// dans l'application relit le serveur, et qu'un achat ne le fait PAS.
  int planStatusReads = 0;

  /// Le portail de facturation : son adresse, ou l'erreur que le serveur
  /// oppose (hors ligne, compte sans client chez le prestataire).
  final String portalUrl;
  final Object? portalError;

  /// Retient la réponse du portail tant qu'un test ne la libère pas : c'est
  /// ainsi que l'attente se voit à l'écran.
  Completer<String>? portalGate;

  /// Combien de fois le portail a été demandé.
  int portalOpenings = 0;

  @override
  Future<PlanStatus> planStatus() async {
    planStatusReads += 1;
    return PlanStatus(
      planName: isPremium ? 'Premium' : 'Gratuit',
      isPremium: isPremium,
      subscription: isPremium
          ? SubscriptionInfo(
              planName: 'Premium',
              state: SubscriptionState.active,
              cancelAtPeriodEnd: false,
              currentPeriodEnd: DateTime.utc(2026, 9, 6),
            )
          : null,
    );
  }

  @override
  Future<List<EntitlementEntry>> entitlements() async => [
    EntitlementEntry(key: 'unlimited_programs', isActive: isPremium),
    EntitlementEntry(key: 'advanced_statistics', isActive: isPremium),
    EntitlementEntry(key: 'premium_exercises', isActive: isPremium),
    const EntitlementEntry(key: 'ai_coaching', isActive: false),
  ];

  @override
  Future<OfferCatalog> offers() async => OfferCatalog(
    checkoutAvailable: checkoutAvailable,
    offers: const [
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
    checkouts.add((offerId: offerId, id: id));
    final error = checkoutError;
    if (error != null) throw error;
    return checkoutUrl;
  }

  @override
  Future<String> startBillingPortal() async {
    portalOpenings += 1;
    final gate = portalGate;
    if (gate != null) return gate.future;
    final error = portalError;
    if (error != null) throw error;
    return portalUrl;
  }
}
