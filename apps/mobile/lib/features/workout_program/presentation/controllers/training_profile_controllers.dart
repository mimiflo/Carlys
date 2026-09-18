import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/training_profile_repository_impl.dart';
import '../../domain/entities/training_profile.dart';

/// Les entrées de génération, lues une fois puis invalidées à l'écriture.
/// Non auto-disposé : les actions le relisent dans des rappels tardifs, et
/// l'écran de génération à venir s'y branchera aussi.
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

  /// Coche ou décoche UN équipement.
  ///
  /// SÉRIALISÉ : deux coches rapides s'enchaînent au lieu de se courir
  /// après — chaque bascule relit l'état serveur À SON TOUR avant de
  /// calculer la liste complète, sinon la seconde écraserait la première
  /// (la liste est un remplacement complet). Un échec ne casse pas la
  /// chaîne : la bascule suivante repart de l'état serveur réel.
  Future<void> toggleEquipment(String slug) {
    final task = _equipmentChain.then((_) => _toggleEquipment(slug));
    // La chaîne avale l'échec pour survivre ; l'appelant, lui, voit le sien.
    _equipmentChain = task.then((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> _toggleEquipment(String slug) async {
    // Une lecture restée en ERREUR se rejouerait telle quelle à chaque
    // bascule (`.future` rend l'échec en cache) : on la relance d'abord —
    // le réseau revenu, la section matériel revit sans passer par
    // « Réessayer ».
    if (_ref.read(trainingProfileProvider).hasError) {
      _ref.invalidate(trainingProfileProvider);
    }
    final current = await _ref.read(trainingProfileProvider.future);
    final owned = current.equipmentSlugs.toSet();
    if (!owned.add(slug)) {
      owned.remove(slug);
    }
    await _patch(equipmentSlugs: owned.toList());
  }

  Future<void> _equipmentChain = Future<void>.value();

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
