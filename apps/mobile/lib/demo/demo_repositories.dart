/// Dépôts en mémoire du MODE DÉMO (flavor `demo` uniquement) — aucun réseau.
///
/// Chaque implémentation respecte le contrat du domaine ; l'état vit le temps
/// du processus. Les valeurs métaboliques sont figées (le vrai calcul reste
/// côté serveur, hors de portée d'une démo hors ligne).
library;

import 'dart:async';

import '../app/restore/app_restore.dart';
import '../core/synchronization/sync_lifecycle.dart';
import '../features/authentication/domain/entities/auth_session_device.dart';
import '../features/authentication/domain/entities/auth_user.dart';
import '../features/authentication/domain/repositories/auth_repository.dart';
import '../features/carlys_profile/domain/entities/carlys_profile.dart';
import '../features/carlys_profile/domain/repositories/carlys_profile_repository.dart';
import '../features/exercises/domain/entities/exercise.dart';
import '../features/exercises/domain/repositories/exercises_repository.dart';
import '../features/notifications/domain/repositories/device_token_repository.dart';
import '../features/nutrition/domain/entities/nutrition.dart';
import '../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../features/nutrition/presentation/controllers/water_controllers.dart';
import '../features/progress/domain/entities/progress.dart';
import '../features/progress/domain/repositories/progress_repository.dart';
import '../features/subscription/domain/entities/subscription.dart';
import '../features/subscription/domain/repositories/subscription_repository.dart';
import 'demo_catalog.dart';
import 'demo_data.dart';

/// Session toujours ouverte ; la connexion accepte n'importe quels
/// identifiants pour laisser explorer les écrans d'authentification.
class DemoAuthRepository implements AuthRepository {
  bool _connected = true;

  /// Le choix de profil Carlys vit ici, comme il vivrait sur le serveur :
  /// `me()` le reflète, donc le rafraîchissement du profil suffit à l'UI —
  /// exactement le flux de production.
  CarlysProfile? _carlysProfile = demoUser.carlysProfile;

  AuthUser get _user => AuthUser(
        id: demoUser.id,
        email: demoUser.email,
        displayName: demoUser.displayName,
        emailVerified: demoUser.emailVerified,
        locale: demoUser.locale,
        timezone: demoUser.timezone,
        carlysProfile: _carlysProfile,
      );

  void chooseCarlysProfile(CarlysProfile profile) {
    _carlysProfile = profile;
  }

  List<AuthSessionDevice> _devices = [
    AuthSessionDevice(
      id: 'demo-device-1',
      current: true,
      createdAt: DateTime.utc(2026, 7, 1),
      lastUsedAt: DateTime.utc(2026, 8, 7),
      deviceName: 'Cet appareil',
      devicePlatform: 'android',
    ),
    AuthSessionDevice(
      id: 'demo-device-2',
      current: false,
      createdAt: DateTime.utc(2026, 6, 15),
      lastUsedAt: DateTime.utc(2026, 8, 2),
      deviceName: 'Tablette du salon',
      devicePlatform: 'android',
    ),
  ];

  @override
  Future<bool> hasStoredSession() async => _connected;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    _connected = true;
    return _user;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _connected = true;
    return _user;
  }

  @override
  Future<void> logout() async => _connected = false;

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<AuthUser> me() async => _user;

  @override
  Future<List<AuthSessionDevice>> sessions() async => _devices;

  @override
  Future<void> revokeSession(String sessionId) async {
    _devices = _devices.where((device) => device.id != sessionId).toList();
  }

  @override
  Future<void> revokeOtherSessions() async {
    _devices = _devices.where((device) => device.current).toList();
  }
}

/// Choix du profil Carlys en mémoire : écrit chez [DemoAuthRepository], que
/// `me()` reflète — le rafraîchissement du profil suffit, comme en ligne.
class DemoCarlysProfileRepository implements CarlysProfileRepository {
  DemoCarlysProfileRepository(this._auth);

  final DemoAuthRepository _auth;

  @override
  Future<void> choose(CarlysProfile profile) async =>
      _auth.chooseCarlysProfile(profile);
}

/// Catalogue embarqué : recherche, filtres et pagination réels.
///
/// La liste vient de `assets/demo/catalog.json`, engendré depuis le seed de
/// l'API — voir `demo_catalog.dart`.
class DemoExercisesRepository implements ExercisesRepository {
  static const _pageSize = 6;

  @override
  Future<ExercisesPage> list({
    ExercisesFilters filters = const ExercisesFilters(),
    String? cursor,
  }) async {
    final catalog = await loadDemoCatalog();
    var filtered = List<ExerciseDetail>.from(catalog.exercises);
    final search = filters.search?.toLowerCase();
    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where((exercise) => exercise.name.toLowerCase().contains(search))
          .toList();
    }
    if (filters.muscleGroupSlug != null) {
      filtered = filtered
          .where(
            (exercise) =>
                exercise.primaryMuscleGroup?.slug == filters.muscleGroupSlug,
          )
          .toList();
    }
    if (filters.difficulty != null) {
      filtered = filtered
          .where((exercise) => exercise.difficulty == filters.difficulty)
          .toList();
    }

    final start = cursor == null
        ? 0
        : filtered.indexWhere((exercise) => exercise.id == cursor) + 1;
    final page = filtered.skip(start).take(_pageSize).toList();
    final hasMore = start + page.length < filtered.length;

    return ExercisesPage(
      items: page,
      nextCursor: hasMore ? page.last.id : null,
      hasMore: hasMore,
      total: filtered.length,
    );
  }

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) async {
    final catalog = await loadDemoCatalog();
    return catalog.exercises.firstWhere(
      (exercise) => exercise.id == idOrSlug || exercise.slug == idOrSlug,
    );
  }

  @override
  Future<List<MuscleGroupRef>> muscleGroups() async =>
      (await loadDemoCatalog()).muscleGroups;
}

/// Statistiques figées par période ; mesures corporelles modifiables.
class DemoProgressRepository implements ProgressRepository {
  final List<BodyMetricEntry> _metrics = [...demoWeights];
  int _nextId = 0;

  @override
  Future<ProgressOverviewEntity> overview(ProgressPeriod period) async {
    final (sessions, sets, volume, duration, buckets) = switch (period) {
      ProgressPeriod.week => (4, 58, 6420.0, 4 * 3300, 7),
      ProgressPeriod.month => (14, 196, 22850.0, 14 * 3300, 5),
      ProgressPeriod.year => (86, 1180, 131400.0, 86 * 3300, 12),
    };
    final perBucket = volume / buckets;
    return ProgressOverviewEntity(
      period: period,
      sessionsCount: sessions,
      setsCount: sets,
      totalVolumeKg: volume,
      totalDurationSeconds: duration,
      points: [
        for (var i = 0; i < buckets; i++)
          ProgressPoint(
            bucketStart:
                DateTime.now().toUtc().subtract(Duration(days: buckets - i)),
            sessionsCount: 1,
            // Variation déterministe autour de la moyenne (pas d'aléatoire).
            volumeKg: perBucket * (0.7 + 0.6 * ((i * 37) % 10) / 10),
          ),
      ],
    );
  }

  @override
  Future<List<PersonalRecordEntry>> records() async => demoRecords;

  @override
  Future<List<BodyMetricEntry>> bodyMetrics({
    BodyMetricKind kind = BodyMetricKind.weightKg,
    int limit = 90,
  }) async {
    return _metrics.where((metric) => metric.kind == kind).toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }

  @override
  Future<BodyMetricEntry> addBodyMetric({
    required BodyMetricKind kind,
    required double value,
    required DateTime measuredAt,
  }) async {
    final metric = BodyMetricEntry(
      id: 'demo-added-${_nextId++}',
      kind: kind,
      value: value,
      measuredAt: measuredAt,
    );
    _metrics.add(metric);
    return metric;
  }

  @override
  Future<void> deleteBodyMetric(String id) async {
    _metrics.removeWhere((metric) => metric.id == id);
  }
}

/// Notifications de démonstration : les préférences vivent en mémoire.
///
/// Sans elle, l'écran Profil de la démonstration appellerait une API qui
/// n'existe pas — un appel voué à l'échec, et un délai d'attente pour rien.
class DemoDeviceTokenRepository implements DeviceTokenRepository {
  final Map<NotificationCategory, bool> _preferences = {};

  @override
  Future<void> register({
    required String token,
    required DevicePlatform platform,
  }) async {}

  @override
  Future<void> unregister(String token) async {}

  @override
  Future<Map<NotificationCategory, bool>> preferences() async => _preferences;

  @override
  Future<void> setPreference(
    NotificationCategory category, {
    required bool enabled,
  }) async {
    _preferences[category] = enabled;
  }
}

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
}

/// Hydratation de la DÉMONSTRATION : un compteur en mémoire, qui démarre à
/// mi-parcours pour que la cellule montre une jauge vivante plutôt qu'un
/// départ à zéro — c'est une vitrine, pas une journée réelle.
class DemoWaterStore implements WaterStore {
  final StreamController<int> _controller = StreamController<int>.broadcast();
  int _milliliters = 1250;

  @override
  Stream<int> watchToday() async* {
    yield _milliliters;
    yield* _controller.stream;
  }

  @override
  Future<int> addToday(int milliliters) async {
    _milliliters = (_milliliters + milliliters).clamp(0, 20000);
    _controller.add(_milliliters);
    return _milliliters;
  }
}

/// Profil complet modifiable ; résultats métaboliques figés et cohérents
/// avec le poids de démonstration (79,8 kg — le vrai calcul est serveur).
class DemoNutritionRepository implements NutritionRepository {
  BiologicalSex? _sex = BiologicalSex.male;
  DateTime? _birthDate = DateTime.utc(1997, 5, 14);
  double? _heightCm = 180;
  ActivityLevel? _activityLevel = ActivityLevel.moderate;
  NutritionGoal? _goal = NutritionGoal.gainMuscle;

  @override
  Future<MetabolismReport> metabolismReport() async {
    final missing = <MetabolismMissingField>[
      if (_sex == null) MetabolismMissingField.sex,
      if (_birthDate == null) MetabolismMissingField.birthDate,
      if (_heightCm == null) MetabolismMissingField.heightCm,
      if (_activityLevel == null) MetabolismMissingField.activityLevel,
    ];
    return MetabolismReport(
      profile: MetabolicProfile(
        sex: _sex,
        birthDate: _birthDate,
        ageYears: _birthDate == null ? null : 29,
        heightCm: _heightCm,
        weightKg: 79.8,
        activityLevel: _activityLevel,
        goal: _goal,
      ),
      missing: missing,
      metabolism: missing.isNotEmpty
          ? null
          : const MetabolismResult(
              bmi: 24.6,
              bmiCategory: BmiCategory.normal,
              bmrKcal: 1783,
              tdeeKcal: 2764,
              targetKcal: 3040,
              proteinG: 144,
              fatG: 84,
              carbsG: 427,
              waterMl: 2793,
            ),
    );
  }

  @override
  Future<void> updateProfile(MetabolicProfileUpdate update) async {
    _sex = update.sex ?? _sex;
    _birthDate = update.birthDate ?? _birthDate;
    _heightCm = update.heightCm ?? _heightCm;
    _activityLevel = update.activityLevel ?? _activityLevel;
    _goal = update.goal ?? _goal;
  }

  // Journal du jour : deux repas déjà saisis, pour que « consommé /
  // objectif » vive dès l'ouverture de la démo.
  final List<MealEntry> _meals = [
    MealEntry(
      id: 'demo-meal-1',
      name: 'Skyr, granola, myrtilles',
      kcal: 380,
      proteinG: 28,
      eatenAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    MealEntry(
      id: 'demo-meal-2',
      name: 'Poulet, riz, brocoli',
      kcal: 640,
      proteinG: 46,
      eatenAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  @override
  Future<List<MealEntry>> mealsBetween(DateTime from, DateTime to) async {
    return _meals
        .where(
          (meal) => !meal.eatenAt.isBefore(from) && meal.eatenAt.isBefore(to),
        )
        .toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
  }

  @override
  Future<MealEntry> addMeal(MealEntry meal) async {
    // Idempotent, comme le serveur : rejouer le même id ne double rien.
    if (_meals.every((entry) => entry.id != meal.id)) {
      _meals.add(meal);
    }
    return meal;
  }

  @override
  Future<void> deleteMeal(String id) async {
    _meals.removeWhere((meal) => meal.id == id);
  }
}

/// Aucune synchronisation en démo : rien à pousser, aucun serveur à joindre.
class DemoSyncLifecycle implements SyncLifecycle {
  @override
  void ensureStarted() {}

  @override
  void dispose() {}
}

/// Aucun rapatriement en démo, pour la même raison — et surtout : ne pas
/// ouvrir la base Drift, dont le mode démo se passe entièrement.
class DemoAppRestore implements AppRestore {
  @override
  void ensureRestored() {}
}
