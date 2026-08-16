import '../entities/subscription.dart';

/// Lecture de l'état d'abonnement — source de vérité : le serveur.
abstract interface class SubscriptionRepository {
  Future<PlanStatus> planStatus();

  Future<List<EntitlementEntry>> entitlements();

  /// Le catalogue d'offres, prix compris.
  Future<OfferCatalog> offers();

  /// Ouvre une page de paiement et rend son adresse.
  ///
  /// [id] est fourni par l'appareil : réappuyer rend la MÊME page, jamais un
  /// second paiement. Aucun droit n'est accordé ici — c'est le webhook signé
  /// qui l'accorde, une fois l'argent encaissé.
  Future<String> startCheckout({required String offerId, required String id});
}
