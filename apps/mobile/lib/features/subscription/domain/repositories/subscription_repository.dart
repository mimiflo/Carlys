import '../entities/subscription.dart';

/// Lecture de l'état d'abonnement — source de vérité : le serveur.
abstract interface class SubscriptionRepository {
  Future<PlanStatus> planStatus();

  Future<List<EntitlementEntry>> entitlements();
}
