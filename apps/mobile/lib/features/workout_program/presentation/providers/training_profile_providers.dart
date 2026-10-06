import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/account_bound_cache.dart';
import '../../../authentication/presentation/controllers/account_session.dart';
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
/// doigt, puis écrit SON champ. Un PATCH réussi laisse au serveur ce que
/// l'écran montre déjà : pas de relecture — avant, chaque choix attendait
/// l'écriture PUIS la relecture. Un refus fait relire : l'écran redit ce
/// que le serveur tient.
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
  Future<void> toggleEquipment(String slug) => _whenShown((shown) {
    final owned = shown.equipmentSlugs.toSet();
    if (!owned.add(slug)) {
      owned.remove(slug);
    }
    return _patch(equipmentSlugs: owned.toList());
  });

  /// Lance [gesture] sur ce que l'écran montre. Rien de montré, ou une
  /// lecture en vol (elle reviendrait ÉCRASER le geste montré d'avance) :
  /// on l'attend d'abord — les gestes ainsi retenus partent dans l'ordre.
  /// Une lecture restée en ERREUR se rejouerait telle quelle (`.future`
  /// rend l'échec en cache) : on la relance.
  Future<void> _whenShown(
    Future<void> Function(TrainingProfile shown) gesture,
  ) {
    final cache = _ref.read(trainingProfileProvider);
    final shown = cache.valueOrNull;
    if (shown != null && !cache.isLoading) return gesture(shown);
    if (cache.hasError) _ref.invalidate(trainingProfileProvider);
    return _ref
        .read(trainingProfileProvider.future)
        .then((_) => _whenShown(gesture));
  }

  /// SÉRIALISÉES : les écritures arrivent au serveur dans l'ordre des
  /// gestes. La chaîne avale l'échec ; l'appelant, lui, voit le sien.
  Future<void> _chain = Future<void>.value();
  int _inFlight = 0;

  /// Ce que le serveur tient, d'après les écritures revenues : la valeur
  /// montrée quand la file était vide, plus chaque PATCH réussi. Un refus y
  /// REVIENT avant de relire — une relecture qui échoue aussi (hors ligne)
  /// garderait sinon le choix refusé à l'écran, Riverpod conservant la
  /// dernière valeur dans l'erreur.
  TrainingProfile? _confirmed;

  /// La session des écritures en vol : le compte qui arrive ne reçoit ni
  /// les écritures ni la valeur confirmée de celui qui part.
  int? _session;
  bool _refused = false;

  Future<void> _patch({
    TrainingExperience? experience,
    int? weeklySessionsTarget,
    int? sessionMinutesTarget,
    List<String>? equipmentSlugs,
  }) => _whenShown((shown) {
    if (_inFlight++ == 0) {
      _confirmed = shown;
      _session = _ref.read(accountSessionProvider);
    }
    TrainingProfile written(TrainingProfile base) => base.copyWith(
      experience: experience,
      weeklySessionsTarget: weeklySessionsTarget,
      sessionMinutesTarget: sessionMinutesTarget,
      equipmentSlugs: equipmentSlugs,
    );
    _ref.read(trainingProfileProvider.notifier).show(written(shown));
    final task = _chain.then((_) async {
      if (!_sameSession) return;
      await _ref
          .read(trainingProfileRepositoryProvider)
          .patch(
            experience: experience,
            weeklySessionsTarget: weeklySessionsTarget,
            sessionMinutesTarget: sessionMinutesTarget,
            equipmentSlugs: equipmentSlugs,
          );
      _confirmed = written(_confirmed ?? shown);
    });
    _chain = task.then((_) {}, onError: (Object _) {});
    return task.then(
      (_) => _settle(),
      onError: (Object error, StackTrace stack) {
        _refused = true;
        _settle();
        Error.throwWithStackTrace(error, stack);
      },
    );
  });

  bool get _sameSession => _ref.read(accountSessionProvider) == _session;

  /// La dernière écriture revenue : après un refus, l'écran revient à la
  /// valeur confirmée, puis relit.
  void _settle() {
    if (--_inFlight > 0) return;
    final confirmed = _confirmed;
    final refused = _refused;
    _confirmed = null;
    _refused = false;
    if (!refused || !_sameSession) return;
    if (confirmed != null) {
      _ref.read(trainingProfileProvider.notifier).show(confirmed);
    }
    _ref.invalidate(trainingProfileProvider);
  }
}

final trainingProfileActionsProvider = Provider<TrainingProfileActions>(
  TrainingProfileActions.new,
);
