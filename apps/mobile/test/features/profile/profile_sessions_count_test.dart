import 'dart:async';

import 'package:carlys_mobile/features/authentication/presentation/controllers/account_bound_cache.dart';
import 'package:carlys_mobile/features/profile/presentation/providers/profile_hub_providers.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/providers/progress_providers.dart';
import 'package:carlys_mobile/features/progression/domain/progression.dart';
import 'package:carlys_mobile/features/progression/domain/reward_engine.dart';
import 'package:carlys_mobile/features/progression/presentation/providers/reward_providers.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/controllers/workout_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_progress_repository.dart';
import '../../support/fake_workout_repository.dart';

/// La tuile « Séances » du profil suit la séance TOUT JUSTE close.
///
/// Le serveur ne compte la 10e séance qu'une fois sa clôture acquittée :
/// close et pas encore synchronisée, elle n'y est pas. La tuile restait à 9
/// quand l'historique local, lui, la voyait déjà.
void main() {
  ProviderContainer build({required int serveur, int? fusionnees}) {
    final container = ProviderContainer(
      overrides: [
        lifetimeStatsProvider.overrideWith(
          () => AccountBoundCache(
            (ref) async => LifetimeStats(completedSessions: serveur, weeks: []),
            none: const LifetimeStats(completedSessions: 0, weeks: []),
          ),
        ),
        rewardFactsProvider.overrideWith(
          (ref) => fusionnees == null
              ? null
              : RewardFacts(
                  reachedTitle: CarlysTitle.apprenti,
                  completedSessions: fusionnees,
                ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<int?> lire(ProviderContainer container) async {
    final sub = container.listen(profileSessionsCountProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(lifetimeStatsProvider.future);
    return container.read(profileSessionsCountProvider).valueOrNull;
  }

  test('la séance close compte avant que le serveur la voie', () async {
    expect(await lire(build(serveur: 9, fusionnees: 10)), 10);
  });

  test('le serveur garde la main sur ce que le téléphone ne voit plus', () {
    // Un téléphone neuf ne rapatrie que 60 séances : 200 au serveur.
    return expectLater(
      lire(build(serveur: 200, fusionnees: 60)),
      completion(200),
    );
  });

  test('faits pas encore prêts : le serveur seul', () async {
    expect(await lire(build(serveur: 9)), 9);
  });

  // Le serveur est RELU quand il acquitte la clôture. Sans cela, un compte
  // restauré — 60 séances rapatriées, 149 au serveur — restait à 149 : le
  // plus grand des deux comptes ne bouge pas quand le local passe de 60 à 61.
  test('compte restauré : la clôture acquittée relit le serveur', () async {
    final historique = StreamController<List<WorkoutHistoryEntry>>();
    addTearDown(historique.close);
    final serveur = _ServeurQuiCompte()
      ..lifetime = const LifetimeStats(completedSessions: 149, weeks: []);
    final container = ProviderContainer(
      overrides: [
        workoutRepositoryProvider.overrideWithValue(
          _HistoriquePilote(historique.stream),
        ),
        progressRepositoryProvider.overrideWithValue(serveur),
        rewardFactsProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);
    // Dans l'appli, les récompenses tiennent l'historique ouvert.
    container.listen(workoutHistoryProvider, (_, _) {});
    final tuile = container.listen(profileSessionsCountProvider, (_, _) {});
    // L'accueil tient la semaine ouverte (et la garde deux minutes).
    container.listen(overviewForPeriodProvider(ProgressPeriod.week), (_, _) {});

    WorkoutHistoryEntry seance(String id, LocalSyncState sync) =>
        WorkoutHistoryEntry(
          session: WorkoutInfo(
            id: id,
            startedAt: DateTime.utc(2026, 9, 26),
            status: WorkoutStatus.completed,
            syncState: sync,
          ),
          totalVolumeKg: 1000,
          setsCount: 12,
        );
    final rapatriees = [
      for (var i = 0; i < 60; i++) seance('r$i', LocalSyncState.synced),
    ];

    historique.add([seance('150e', LocalSyncState.pending), ...rapatriees]);
    await container.read(lifetimeStatsProvider.future);
    await container.read(overviewForPeriodProvider(ProgressPeriod.week).future);
    await pumpEventQueue();
    expect(tuile.read().valueOrNull, 149);
    // Le premier chargement de l'historique n'est pas un acquittement.
    expect(serveur.lectures, 1);

    // Le serveur écrit la 150e, puis la file l'acquitte.
    serveur.lifetime = const LifetimeStats(completedSessions: 150, weeks: []);
    historique.add([seance('150e', LocalSyncState.synced), ...rapatriees]);
    await pumpEventQueue();
    expect(tuile.read().valueOrNull, 150);
    expect(serveur.lectures, 2);
    // La semaine aussi : sans cela, l'onglet Progrès montrait celle d'avant.
    expect(serveur.semaines, 2);
  });
}

/// Le serveur, qui compte ses lectures des compteurs de vie entière.
class _ServeurQuiCompte extends FakeProgressRepository {
  int lectures = 0;
  int semaines = 0;

  @override
  Future<ProgressOverviewEntity> overview(ProgressPeriod period) {
    if (period == ProgressPeriod.week) semaines++;
    return super.overview(period);
  }

  @override
  Future<LifetimeStats> lifetimeStats() {
    lectures++;
    return super.lifetimeStats();
  }
}

/// L'historique, émis à la main : chaque `add` est un état de la base.
class _HistoriquePilote extends FakeWorkoutRepository {
  _HistoriquePilote(this._flux);

  final Stream<List<WorkoutHistoryEntry>> _flux;

  @override
  Stream<List<WorkoutHistoryEntry>> watchHistory() => _flux;
}
