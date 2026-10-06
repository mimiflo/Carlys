import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/repositories/training_goal_repository.dart';

/// Dépôt pilotable des tests : enregistre les choix, peut simuler la panne.
class FakeTrainingGoalRepository implements TrainingGoalRepository {
  FakeTrainingGoalRepository({this.failChoose = false});

  bool failChoose;
  final List<TrainingGoal> chosen = [];

  /// Tant qu'elle n'est pas complétée, le serveur « réfléchit » : de quoi
  /// voir ce que l'écran montre AVANT sa réponse.
  Completer<void>? gate;

  @override
  Future<void> choose(TrainingGoal goal) async {
    await gate?.future;
    if (failChoose) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
    chosen.add(goal);
  }
}
