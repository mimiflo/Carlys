import 'dart:async';

import 'package:carlys_mobile/features/subscription/domain/entities/subscription.dart';
import 'package:carlys_mobile/features/subscription/domain/repositories/subscription_repository.dart';

import 'api_contract.dart';

/// Les droits que le serveur rend (`ENTITLEMENT_KEYS`, TOUS, actifs ou non)
/// et ceux que Premium accorde (`PREMIUM_ENTITLEMENT_KEYS`), lus dans le
/// contrat : recopiés ici, ils avaient divergé (quatre lignes au lieu de
/// neuf, dont deux droits accordés jamais montrés).
final List<String> entitlementKeys = contractStrings(
  'subscriptions.ts',
  RegExp(r'ENTITLEMENT_KEYS = \[([\s\S]*?)\]'),
);
final List<String> premiumEntitlementKeys = contractStrings(
  'subscriptions.ts',
  RegExp(
    r'PREMIUM_ENTITLEMENT_KEYS: readonly EntitlementKey\[\] = \[([\s\S]*?)\]',
  ),
);

/// SubscriptionRepository de test — état en mémoire, aucune requête réseau.
class FakeSubscriptionRepository implements SubscriptionRepository {
  FakeSubscriptionRepository({
    this.isPremium = false,
    this._coaching,
    this.checkoutAvailable = false,
    this.checkoutUrl = 'https://paiement.exemple/session',
    this.checkoutError,
    this.portalUrl = 'https://portail.exemple/session',
    this.portalError,
    this.offersError,
    this.entitlementsError,
  });

  /// Mutable : un test simule le webhook qui accorde Premium PENDANT que
  /// l'utilisateur est parti payer, puis vérifie que le retour le relit.
  bool isPremium;

  /// Le droit au coach (`ai_coaching`) : celui de Premium par défaut, comme
  /// le plan le donne côté serveur, ou forcé par une épreuve du coach (un
  /// ANCIEN abonné qui relit son fil sans pouvoir y écrire).
  final bool? _coaching;
  bool get coaching => _coaching ?? isPremium;

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

  /// L'échec que le CATALOGUE d'offres oppose, s'il y en a un. Sans offres
  /// il n'y a plus de porte d'achat du tout : l'écran doit le dire, pas la
  /// faire disparaître.
  final Object? offersError;

  /// L'échec que `GET /entitlements` oppose (délai, 5xx), s'il y en a un.
  final Object? entitlementsError;

  /// Combien de fois les droits ont été lus.
  int entitlementsReads = 0;

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
              currentPeriodEnd: subscriptionRenewalDate(),
            )
          : null,
    );
  }

  @override
  Future<List<EntitlementEntry>> entitlements() async {
    entitlementsReads += 1;
    final error = entitlementsError;
    if (error != null) throw error;
    return [
      for (final key in entitlementKeys)
        EntitlementEntry(
          key: key,
          isActive: key == 'ai_coaching'
              ? coaching
              : isPremium && premiumEntitlementKeys.contains(key),
        ),
    ];
  }

  @override
  Future<OfferCatalog> offers() async {
    final error = offersError;
    if (error != null) throw error;
    return OfferCatalog(
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
  }

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

/// L'échéance d'un abonnement actif : dans un peu plus de trois semaines.
///
/// Elle était figée au 6 septembre 2026, et la carte la rend SANS ANNÉE
/// (« Renouvellement le dim. 6 sept. »). Passé cette date, l'écran d'ARGENT,
/// celui qui doit inspirer le plus confiance, annonçait un renouvellement
/// déjà révolu.
///
/// PUBLIQUE, pour que les épreuves dérivent le libellé attendu au lieu de
/// coder un nom de mois : c'est ce couplage-là qui avait figé la date.
DateTime subscriptionRenewalDate() =>
    DateTime.now().toUtc().add(const Duration(days: 23));
