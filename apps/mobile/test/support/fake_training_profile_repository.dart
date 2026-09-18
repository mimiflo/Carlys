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

  /// Chaque écriture de matériel, telle qu'envoyée : l'état complet.
  final List<List<String>> equipmentWrites = [];

  @override
  Future<TrainingProfile> fetch() async {
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
    if (equipmentSlugs != null) {
      equipmentWrites.add(List.of(equipmentSlugs));
    }
    profile = TrainingProfile(
      goal: profile.goal,
      experience: experience ?? profile.experience,
      weeklySessionsTarget:
          weeklySessionsTarget ?? profile.weeklySessionsTarget,
      sessionMinutesTarget:
          sessionMinutesTarget ?? profile.sessionMinutesTarget,
      equipmentSlugs: equipmentSlugs ?? profile.equipmentSlugs,
    );
  }
}
