import 'package:carlys_mobile/features/subscription/domain/entities/subscription.dart';
import 'package:carlys_mobile/features/subscription/domain/repositories/subscription_repository.dart';

/// SubscriptionRepository de test — état en mémoire, aucune requête réseau.
class FakeSubscriptionRepository implements SubscriptionRepository {
  FakeSubscriptionRepository({this.isPremium = false});

  final bool isPremium;

  @override
  Future<PlanStatus> planStatus() async => PlanStatus(
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

  @override
  Future<List<EntitlementEntry>> entitlements() async => [
        EntitlementEntry(key: 'unlimited_programs', isActive: isPremium),
        EntitlementEntry(key: 'advanced_statistics', isActive: isPremium),
        EntitlementEntry(key: 'premium_exercises', isActive: isPremium),
        const EntitlementEntry(key: 'ai_coaching', isActive: false),
      ];
}
