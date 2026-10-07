import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/account_bound_cache.dart';
import '../../../authentication/presentation/providers/ahead_writes.dart';
import '../../data/repositories/training_profile_repository_impl.dart';
import '../../domain/entities/training_profile.dart';

/// Les entrées de génération, lues une fois puis invalidées à l'écriture.
/// Non auto-disposé : les actions le relisent dans des rappels tardifs, et
/// l'écran de génération à venir s'y branchera aussi.
///
/// Cache DE COMPTE ([AccountBoundCache]) : l'écran le lit par `valueOrNull`,
/// et le niveau, le rythme et le matériel du compte parti s'y montraient au
/// suivant le temps de sa première lecture — ou pour de bon si elle
/// échouait.
final trainingProfileProvider = accountBoundCache<TrainingProfile>(
  (ref) => ref.read(trainingProfileRepositoryProvider).fetch(),
  none: const TrainingProfile(
    goal: null,
    experience: null,
    weeklySessionsTarget: null,
    sessionMinutesTarget: null,
    equipmentSlugs: [],
  ),
);

/// Écritures des entrées de génération : chaque geste se VOIT sous le
/// doigt, puis écrit SON champ ([AheadWrites]). Un refus fait relire :
/// l'écran redit ce que le serveur tient.
///
/// `Provider` simple (PAS autoDispose) : la référence est capturée dans des
/// callbacks tardifs — même leçon que les actions communauté.
class TrainingProfileActions {
  TrainingProfileActions(Ref ref)
    : _ref = ref,
      _writes = AheadWrites(ref, trainingProfileProvider);

  final Ref _ref;
  final AheadWrites<TrainingProfile> _writes;

  Future<void> setExperience(TrainingExperience experience) =>
      _patch(experience: experience);

  Future<void> setWeeklySessions(int sessions) =>
      _patch(weeklySessionsTarget: sessions);

  Future<void> setSessionMinutes(int minutes) =>
      _patch(sessionMinutesTarget: minutes);

  /// Rythme ET durée en UNE écriture : les poser un par un laissait, sur une
  /// panne entre les deux, un rythme à moitié appliqué.
  Future<void> setRhythm({required int weeklySessions, required int minutes}) =>
      _patch(
        weeklySessionsTarget: weeklySessions,
        sessionMinutesTarget: minutes,
      );

  /// Coche ou décoche UN équipement, sur la liste MONTRÉE — elle porte déjà
  /// les coches précédentes encore en vol : deux coches rapides ne
  /// s'écrasent pas (la liste est un remplacement complet).
  Future<void> toggleEquipment(String slug) => _writes.whenShown(
    (shown) =>
        setEquipmentOwned([slug], owned: !shown.equipmentSlugs.contains(slug)),
  );

  /// Coche ([owned] vrai) ou décoche TOUT un groupe en une écriture, sur la
  /// liste montrée comme une coche seule.
  Future<void> setEquipmentOwned(
    Iterable<String> slugs, {
    required bool owned,
  }) => _writes.whenShown((shown) {
    final kit = shown.equipmentSlugs.toSet();
    if (owned) {
      kit.addAll(slugs);
    } else {
      kit.removeAll(slugs);
    }
    return _patch(equipmentSlugs: kit.toList());
  });

  Future<void> _patch({
    TrainingExperience? experience,
    int? weeklySessionsTarget,
    int? sessionMinutesTarget,
    List<String>? equipmentSlugs,
  }) => _writes.write(
    (base) => base.copyWith(
      experience: experience,
      weeklySessionsTarget: weeklySessionsTarget,
      sessionMinutesTarget: sessionMinutesTarget,
      equipmentSlugs: equipmentSlugs,
    ),
    () => _ref
        .read(trainingProfileRepositoryProvider)
        .patch(
          experience: experience,
          weeklySessionsTarget: weeklySessionsTarget,
          sessionMinutesTarget: sessionMinutesTarget,
          equipmentSlugs: equipmentSlugs,
        ),
  );
}

final trainingProfileActionsProvider = Provider<TrainingProfileActions>(
  TrainingProfileActions.new,
);
