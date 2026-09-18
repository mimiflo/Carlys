import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/training_profile_repository_impl.dart';
import '../../domain/entities/training_profile.dart';

/// Les entrées de génération, lues une fois puis invalidées à l'écriture.
/// Non auto-disposé : le profil et l'écran de préparation les lisent.
final trainingProfileProvider = FutureProvider<TrainingProfile>((ref) {
  return ref.read(trainingProfileRepositoryProvider).fetch();
});

/// Écritures des entrées de génération : chaque geste écrit SON champ puis
/// invalide la lecture — l'écran reflète toujours l'état serveur, jamais un
/// état local optimiste qui divergerait.
///
/// `Provider` simple (PAS autoDispose) : la référence est capturée dans des
/// callbacks tardifs — même leçon que les actions communauté.
class TrainingProfileActions {
  TrainingProfileActions(this._ref);

  final Ref _ref;

  Future<void> setExperience(TrainingExperience experience) =>
      _patch(experience: experience);

  Future<void> setWeeklySessions(int sessions) =>
      _patch(weeklySessionsTarget: sessions);

  Future<void> setSessionMinutes(int minutes) =>
      _patch(sessionMinutesTarget: minutes);

  /// Remplacement COMPLET de la liste de matériel.
  Future<void> setEquipment(List<String> slugs) =>
      _patch(equipmentSlugs: slugs);

  Future<void> _patch({
    TrainingExperience? experience,
    int? weeklySessionsTarget,
    int? sessionMinutesTarget,
    List<String>? equipmentSlugs,
  }) async {
    await _ref
        .read(trainingProfileRepositoryProvider)
        .patch(
          experience: experience,
          weeklySessionsTarget: weeklySessionsTarget,
          sessionMinutesTarget: sessionMinutesTarget,
          equipmentSlugs: equipmentSlugs,
        );
    _ref.invalidate(trainingProfileProvider);
  }
}

final trainingProfileActionsProvider = Provider<TrainingProfileActions>(
  TrainingProfileActions.new,
);
