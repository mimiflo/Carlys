import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../authentication/presentation/controllers/account_session.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/repositories/training_goal_repository_impl.dart';
import '../../domain/entities/training_goal.dart';

/// Choix de l'objectif d'entraînement : la sélection se VOIT sous le doigt
/// ([_shownGoalProvider]), puis s'écrit au serveur et rafraîchit
/// l'utilisateur — `AuthUser.trainingGoal` reprend alors la main. Un refus
/// efface le choix montré : l'écran redit ce que le serveur tient. Avant, la
/// carte ne se cochait qu'après deux allers-retours.
///
/// `Provider` simple (PAS autoDispose) : la référence est capturée dans des
/// callbacks tardifs — même leçon que les actions communauté.
class TrainingGoalActions {
  static const _logger = AppLogger('TrainingGoalActions');

  TrainingGoalActions(this._ref) {
    // Un objectif gardé faute de session relue (voir [choose]) cède à la
    // prochaine relecture, venue d'ailleurs — sauf écriture en vol.
    _ref.listen(authControllerProvider.select((auth) => auth.user), (_, _) {
      if (_inFlight == 0) _show(null);
    });
  }

  final Ref _ref;

  /// SÉRIALISÉE : deux choix rapides arrivent au serveur dans l'ordre, le
  /// dernier gagne. La chaîne avale l'échec ; l'appelant voit le sien.
  Future<void> _chain = Future<void>.value();

  /// Choix lancés et pas encore revenus : seul le dernier efface ce qui est
  /// montré.
  int _inFlight = 0;

  Future<void> choose(TrainingGoal goal) {
    final session = _ref.read(accountSessionProvider);
    _inFlight++;
    _show(goal);
    final task = _chain.then((_) => _write(goal, session));
    _chain = task.then((_) {}, onError: (Object _) {});
    return task.then(
      (keep) {
        // Écrit mais session non relue : le choix montré reste, c'est celui
        // que le serveur tient désormais.
        if (--_inFlight == 0 && !keep) _show(null);
      },
      onError: (Object error, StackTrace stack) {
        if (--_inFlight == 0) _show(null);
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  /// Écrit ; rend vrai quand le choix écrit n'a pas pu être relu.
  Future<bool> _write(TrainingGoal goal, int? session) async {
    // Le compte a changé pendant l'attente : le choix de l'autre ne part
    // pas avec le jeton de celui-ci.
    if (_ref.read(accountSessionProvider) != session) return false;
    await _ref.read(trainingGoalRepositoryProvider).choose(goal);
    // Le choix serveur a RÉUSSI : un rafraîchissement de session qui échoue
    // juste après ne doit pas le déguiser en échec du choix.
    try {
      await _ref.read(authControllerProvider.notifier).refreshProfile();
      return false;
    } on Exception catch (error) {
      _logger.warning('Session non rafraîchie après le choix', error: error);
      return true;
    }
  }

  void _show(TrainingGoal? goal) =>
      _ref.read(_shownGoalProvider.notifier).state = goal;
}

/// Le choix en vol, montré d'avance ; `null` quand rien n'est en vol. Il
/// dépend de la session : le choix d'un compte parti ne se montre jamais au
/// suivant.
final _shownGoalProvider = StateProvider<TrainingGoal?>((ref) {
  ref.watch(accountSessionProvider);
  return null;
});

final trainingGoalActionsProvider = Provider<TrainingGoalActions>(
  TrainingGoalActions.new,
);

/// Objectif d'entraînement de l'utilisateur courant, ou `null` tant qu'il
/// n'est pas choisi : `null` signifie « pas encore décidé », jamais un
/// objectif par défaut.
final currentTrainingGoalProvider = Provider<TrainingGoal?>((ref) {
  return ref.watch(_shownGoalProvider) ??
      ref.watch(authControllerProvider).user?.trainingGoal;
});
