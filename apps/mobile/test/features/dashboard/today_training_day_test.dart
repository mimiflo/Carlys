import 'package:carlys_mobile/core/utilities/current_day.dart';
import 'package:carlys_mobile/features/dashboard/presentation/providers/home_day_providers.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/controllers/workout_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';

/// LE JOUR DE LA TUILE « ENTRAÎNEMENT » EST LE JOUR COURANT.
///
/// `todayTrainingProvider` lisait `DateTime.now()` une fois, à la
/// construction. L'accueil ne quitte jamais la pile du shell : passé minuit,
/// la tuile félicitait donc encore pour la séance de la VEILLE, et la phrase
/// d'état qui en dépend répétait « Séance faite aujourd'hui. Beau travail. »
///
/// Le défaut avait déjà été corrigé sur la semaine de constance et sur la
/// maxime, chacune par `currentDayProvider` ; cette tuile-là était restée en
/// arrière.
void main() {
  WorkoutHistoryEntry seance(DateTime startedAt) => WorkoutHistoryEntry(
    session: WorkoutInfo(
      id: 'w-1',
      name: 'Push A',
      status: WorkoutStatus.completed,
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 50)),
      durationSeconds: 3000,
      syncState: LocalSyncState.synced,
    ),
    setsCount: 12,
    totalVolumeKg: 2400,
  );

  /// Un conteneur dont le JOUR est imposé, et dont l'historique porte une
  /// séance faite hier.
  Future<ProviderContainer> conteneur(DateTime jour) async {
    final hier = DateTime.now().subtract(const Duration(days: 1));
    final container = ProviderContainer(
      overrides: [
        currentDayProvider.overrideWithValue(jour),
        workoutRepositoryProvider.overrideWithValue(
          FakeWorkoutRepository()..history = [seance(hier)],
        ),
      ],
    );
    addTearDown(container.dispose);
    // L'historique est un flux : il faut le laisser arriver avant de lire ce
    // qu'on en déduit.
    await container.read(workoutHistoryProvider.future);
    return container;
  }

  DateTime minuitDe(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  test('HIER, la séance d’hier remplit la tuile', () async {
    final hier = DateTime.now().subtract(const Duration(days: 1));
    final container = await conteneur(minuitDe(hier));

    expect(container.read(todayTrainingProvider).value, 'Push A');
    expect(
      container.read(homeSubtitleProvider),
      'Séance faite aujourd’hui. Beau travail.',
    );
  });

  test('AUJOURD’HUI, cette même séance n’est plus celle du jour', () async {
    // C'est EXACTEMENT le passage de minuit : rien n'a changé dans
    // l'historique, seul le jour courant a avancé. Avec un `DateTime.now()`
    // figé au lancement, la tuile continuait de nommer « Push A ».
    final container = await conteneur(minuitDe(DateTime.now()));

    expect(container.read(todayTrainingProvider).value, 'À faire');
    expect(
      container.read(homeSubtitleProvider),
      isNot('Séance faite aujourd’hui. Beau travail.'),
    );
  });

  test('une séance EN COURS passe avant le jour, quel qu’il soit', () async {
    // La séance en cours est un fait présent : elle ne dépend d'aucun jour
    // civil, et la tuile doit la montrer même si le jour a tourné.
    final container = ProviderContainer(
      overrides: [
        currentDayProvider.overrideWithValue(
          minuitDe(DateTime.now().add(const Duration(days: 3))),
        ),
        workoutRepositoryProvider.overrideWithValue(
          FakeWorkoutRepository()
            ..active = WorkoutWithSets(
              session: WorkoutInfo(
                id: 'w-active',
                name: 'Jambes',
                status: WorkoutStatus.inProgress,
                startedAt: DateTime.now(),
                syncState: LocalSyncState.pending,
              ),
              sets: const [],
            ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeWorkoutProvider.future);

    final tuile = container.read(todayTrainingProvider);
    expect(tuile.value, 'Jambes');
    expect(tuile.detail, 'en cours');
  });
}
