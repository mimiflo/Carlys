/// Surcharges Riverpod du MODE DÉMO (flavor `demo` uniquement).
///
/// Branchées par `bootstrap()` quand `CARLYS_FLAVOR=demo` : l'application
/// tourne alors entièrement hors ligne sur les dépôts en mémoire de
/// `demo_repositories.dart`. Les séances restent réelles (Drift local) —
/// seule la synchronisation est désactivée.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/synchronization/sync_lifecycle.dart';
import '../features/authentication/data/repositories/auth_repository_impl.dart';
import '../features/exercises/data/repositories/exercises_repository_impl.dart';
import '../features/nutrition/data/repositories/nutrition_repository_impl.dart';
import '../features/progress/data/repositories/progress_repository_impl.dart';
import '../features/subscription/data/repositories/subscription_repository_impl.dart';
import 'demo_repositories.dart';

List<Override> demoOverrides() => [
      authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
      exercisesRepositoryProvider.overrideWithValue(DemoExercisesRepository()),
      progressRepositoryProvider.overrideWithValue(DemoProgressRepository()),
      subscriptionRepositoryProvider
          .overrideWithValue(DemoSubscriptionRepository()),
      nutritionRepositoryProvider.overrideWithValue(DemoNutritionRepository()),
      syncLifecycleProvider.overrideWithValue(DemoSyncLifecycle()),
    ];
