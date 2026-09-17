import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/repositories/training_goal_repository_impl.dart';
import '../../domain/entities/training_goal.dart';

/// Choix de l'objectif d'entraînement : écrit au serveur PUIS rafraîchit
/// l'utilisateur — la sélection affichée vient toujours de
/// `AuthUser.trainingGoal`, une seule source de vérité.
///
/// `Provider` simple (PAS autoDispose) : la référence est capturée dans des
/// callbacks tardifs — même leçon que les actions communauté.
class TrainingGoalActions {
  TrainingGoalActions(this._ref);

  final Ref _ref;

  Future<void> choose(TrainingGoal goal) async {
    await _ref.read(trainingGoalRepositoryProvider).choose(goal);
    await _ref.read(authControllerProvider.notifier).refreshProfile();
  }
}

final trainingGoalActionsProvider = Provider<TrainingGoalActions>(
  TrainingGoalActions.new,
);

/// Objectif d'entraînement de l'utilisateur courant, ou `null` tant qu'il
/// n'est pas choisi : `null` signifie « pas encore décidé », jamais un
/// objectif par défaut.
final currentTrainingGoalProvider = Provider<TrainingGoal?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return switch (auth) {
    AuthAuthenticated(:final user) => user?.trainingGoal,
    _ => null,
  };
});
