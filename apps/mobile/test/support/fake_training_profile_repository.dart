import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/domain/repositories/training_profile_repository.dart';

/// Dépôt pilotable des tests : un état en mémoire, les écritures de
/// matériel journalisées (la liste COMPLÈTE à chaque geste), la panne
/// simulable.
class FakeTrainingProfileRepository implements TrainingProfileRepository {
  FakeTrainingProfileRepository({TrainingProfile? initial})
    : profile =
          initial ??
          const TrainingProfile(
            goal: null,
            experience: null,
            weeklySessionsTarget: null,
            sessionMinutesTarget: null,
            equipmentSlugs: [],
          );

  TrainingProfile profile;
  bool failFetch = false;
  bool failPatch = false;
  int fetches = 0;

  /// Tant qu'elle n'est pas complétée, l'écriture est « en vol ».
  Completer<void>? gate;

  /// Chaque écriture de matériel, telle qu'envoyée : l'état complet.
  final List<List<String>> equipmentWrites = [];

  @override
  Future<TrainingProfile> fetch() async {
    fetches++;
    if (failFetch) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
    return profile;
  }

  @override
  Future<void> patch({
    TrainingExperience? experience,
    int? weeklySessionsTarget,
    int? sessionMinutesTarget,
    List<String>? equipmentSlugs,
  }) async {
    await gate?.future;
    if (failPatch) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
    if (equipmentSlugs != null) {
      equipmentWrites.add(List.of(equipmentSlugs));
    }
    profile = profile.copyWith(
      experience: experience,
      weeklySessionsTarget: weeklySessionsTarget,
      sessionMinutesTarget: sessionMinutesTarget,
      equipmentSlugs: equipmentSlugs,
    );
  }
}
