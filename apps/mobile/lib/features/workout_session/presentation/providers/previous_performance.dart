import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/workout_repository_impl.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_controllers.dart';

/// Nombre de séances passées inspectées pour retrouver une performance :
/// au-delà, le rappel « PRÉCÉDENT … » n'a plus de valeur d'entraînement.
const int _inspectedPastSessions = 8;

/// Dernière performance enregistrée pour un exercice, séances passées
/// comprises. `null` quand l'exercice n'a jamais été chargé/répété.
///
/// L'historique n'est lu que pour se recalculer quand une séance se clôt.
final previousPerformanceProvider = FutureProvider.autoDispose
    .family<WorkoutSetEntry?, String>((ref, exerciseName) async {
      await ref.watch(workoutHistoryProvider.future);
      return ref
          .watch(workoutRepositoryProvider)
          .previousPerformance(exerciseName, lookback: _inspectedPastSessions);
    });
