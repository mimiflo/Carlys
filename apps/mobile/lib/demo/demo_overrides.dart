/// Surcharges Riverpod du MODE DÉMO (flavor `demo` uniquement).
///
/// Branchées par `bootstrap()` quand `CARLYS_FLAVOR=demo` : l'application
/// tourne alors entièrement hors ligne sur les dépôts en mémoire de
/// `demo_repositories.dart` et `demo_workouts.dart` — y compris les séances,
/// dont l'historique est pré-rempli pour que l'accueil, le calendrier et la
/// progression aient de quoi s'afficher sans compte ni serveur.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/restore/app_restore.dart';
import '../core/synchronization/sync_lifecycle.dart';
import '../features/authentication/data/repositories/auth_repository_impl.dart';
import '../features/carlys_profile/data/repositories/carlys_profile_repository_impl.dart';
import '../features/coaching/data/repositories/coach_repository_impl.dart';
import '../features/coaching/data/repositories/coach_session_launcher.dart';
import '../features/community/data/repositories/community_repository_impl.dart';
import '../features/exercises/data/repositories/exercises_repository_impl.dart';
import '../features/notifications/data/repositories/device_token_repository_impl.dart';
import '../features/nutrition/data/repositories/nutrition_repository_impl.dart';
import '../features/nutrition/presentation/controllers/water_controllers.dart';
import '../features/progress/data/repositories/progress_repository_impl.dart';
import '../features/subscription/data/repositories/subscription_repository_impl.dart';
import '../features/workout_program/data/repositories/program_repository_impl.dart';
import '../features/workout_session/data/repositories/workout_repository_impl.dart';
import '../features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'demo_coach.dart';
import 'demo_community.dart';
import 'demo_programs.dart';
import 'demo_repositories.dart';
import 'demo_templates.dart';
import 'demo_workouts.dart';

List<Override> demoOverrides() {
  // Les modèles lancent de VRAIES séances de démonstration : les deux dépôts
  // partagent donc la même instance, comme en production ils partagent la
  // même base locale.
  final workouts = DemoWorkoutRepository();
  // Le choix de profil Carlys écrit chez le dépôt d'authentification, que
  // `me()` reflète : même instance, même flux qu'en production.
  final auth = DemoAuthRepository();

  return [
    authRepositoryProvider.overrideWithValue(auth),
    carlysProfileRepositoryProvider
        .overrideWithValue(DemoCarlysProfileRepository(auth)),
    coachRepositoryProvider.overrideWithValue(DemoCoachRepository()),
    coachSessionLauncherProvider
        .overrideWithValue(DemoCoachSessionLauncher(workouts)),
    exercisesRepositoryProvider.overrideWithValue(DemoExercisesRepository()),
    progressRepositoryProvider.overrideWithValue(DemoProgressRepository()),
    subscriptionRepositoryProvider
        .overrideWithValue(DemoSubscriptionRepository()),
    nutritionRepositoryProvider.overrideWithValue(DemoNutritionRepository()),
    // L'hydratation vit dans Drift : sans cette substitution, la
    // démonstration ouvrirait une base pour un simple compteur.
    waterStoreProvider.overrideWithValue(DemoWaterStore()),
    programRepositoryProvider.overrideWithValue(DemoProgramRepository()),
    communityRepositoryProvider.overrideWithValue(DemoCommunityRepository()),
    workoutRepositoryProvider.overrideWithValue(workouts),
    workoutTemplateRepositoryProvider
        .overrideWithValue(DemoWorkoutTemplateRepository(workouts)),
    // Sans lui, l'écran Profil de la démonstration appellerait une API
    // absente : un échec certain, et une attente pour rien.
    deviceTokenRepositoryProvider
        .overrideWithValue(DemoDeviceTokenRepository()),
    syncLifecycleProvider.overrideWithValue(DemoSyncLifecycle()),
    appRestoreProvider.overrideWithValue(DemoAppRestore()),
  ];
}
