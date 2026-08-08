/// Dépôts en mémoire du MODE DÉMO (flavor `demo` uniquement) — aucun réseau.
///
/// Chaque implémentation respecte le contrat du domaine ; l'état vit le temps
/// du processus. Les valeurs métaboliques sont figées (le vrai calcul reste
/// côté serveur, hors de portée d'une démo hors ligne).
library;

import '../core/synchronization/sync_lifecycle.dart';
import '../features/authentication/domain/entities/auth_session_device.dart';
import '../features/authentication/domain/entities/auth_user.dart';
import '../features/authentication/domain/repositories/auth_repository.dart';
import '../features/exercises/domain/entities/exercise.dart';
import '../features/exercises/domain/repositories/exercises_repository.dart';
import '../features/nutrition/domain/entities/nutrition.dart';
import '../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../features/progress/domain/entities/progress.dart';
import '../features/progress/domain/repositories/progress_repository.dart';
import '../features/subscription/domain/entities/subscription.dart';
import '../features/subscription/domain/repositories/subscription_repository.dart';
import 'demo_data.dart';

/// Session toujours ouverte ; la connexion accepte n'importe quels
/// identifiants pour laisser explorer les écrans d'authentification.
class DemoAuthRepository implements AuthRepository {
  bool _connected = true;

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
    return demoUser;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _connected = true;
    return demoUser;
  }

  @override
  Future<void> logout() async => _connected = false;

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<AuthUser> me() async => demoUser;

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

/// Catalogue en mémoire : recherche, filtres et pagination réels.
class DemoExercisesRepository implements ExercisesRepository {
  static const _pageSize = 6;

  @override
  Future<ExercisesPage> list({
    ExercisesFilters filters = const ExercisesFilters(),
    String? cursor,
  }) async {
    var filtered = List<ExerciseDetail>.from(demoExercises);
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
    );
  }

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) async =>
      demoExercises.firstWhere(
        (exercise) => exercise.id == idOrSlug || exercise.slug == idOrSlug,
      );

  @override
  Future<List<MuscleGroupRef>> muscleGroups() async => demoMuscleGroups;
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
            bucketStart: DateTime.now()
                .toUtc()
                .subtract(Duration(days: buckets - i)),
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
}

/// Aucune synchronisation en démo : rien à pousser, aucun serveur à joindre.
class DemoSyncLifecycle implements SyncLifecycle {
  @override
  void ensureStarted() {}

  @override
  void dispose() {}
}
