import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/subscription_repository_impl.dart';
import '../../domain/entities/subscription.dart';

/// Plan effectif de l'utilisateur (décidé côté serveur).
final planStatusProvider = FutureProvider.autoDispose<PlanStatus>((ref) {
  return ref.watch(subscriptionRepositoryProvider).planStatus();
});

/// Droits effectifs, dans l'ordre servi par le serveur.
final entitlementsProvider =
    FutureProvider.autoDispose<List<EntitlementEntry>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).entitlements();
});
