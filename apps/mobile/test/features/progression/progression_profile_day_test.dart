import 'package:carlys_mobile/core/utilities/current_day.dart';
import 'package:carlys_mobile/features/academy/presentation/providers/academy_progress_providers.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/progression_controllers.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/controllers/workout_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE PROFIL DE PROGRESSION SUIT LE CALENDRIER, pas la dernière séance.
///
/// Le provider est permanent et l'accueil l'observe sans cesse. Il lisait
/// `DateTime.now()` : « aujourd'hui » restait celui de la dernière écriture
/// de séance, et sur une application restée ouverte plusieurs jours, les
/// fenêtres de 28 jours ne glissaient plus.
void main() {
  test('passer minuit recalcule le profil', () async {
    var jour = DateTime(2026, 9, 24);
    final container = ProviderContainer(
      overrides: [
        currentDayProvider.overrideWith((ref) => jour),
        academyProgressProvider.overrideWith((ref) => null),
        workoutHistoryProvider.overrideWith(
          (ref) => Stream.value([
            WorkoutHistoryEntry(
              session: WorkoutInfo(
                id: 'seance-1',
                startedAt: DateTime(2026, 9, 1, 10),
                status: WorkoutStatus.completed,
                syncState: LocalSyncState.synced,
              ),
              totalVolumeKg: 4000,
              setsCount: 12,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(progressionProfileProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(workoutHistoryProvider.future);
    final avant = container.read(progressionProfileProvider);
    expect(avant, isNotNull);

    // Un mois plus tard, sans nouvelle séance : la séance du 1er sort de la
    // fenêtre, le profil doit le voir.
    jour = DateTime(2026, 10, 25);
    container.invalidate(currentDayProvider);

    final apres = container.read(progressionProfileProvider);
    expect(identical(apres, avant), isFalse);
  });
}
