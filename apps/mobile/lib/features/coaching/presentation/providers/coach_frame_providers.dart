import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../workout_program/presentation/providers/training_goal_providers.dart';
import '../../../workout_program/presentation/providers/training_profile_providers.dart';
import '../utils/coach_frame.dart';

/// Ce qui manque au coach AVANT qu'il réfléchisse (objectif, niveau,
/// matériel), d'après ce qui est DÉJÀ lu : sans compte, ou un profil pas
/// encore là, hors ligne, rien ne retient jamais une question.
final coachFrameMissingProvider = Provider<List<String>>((ref) {
  if (ref.watch(authControllerProvider).user == null) return const [];
  final profile = ref.watch(trainingProfileProvider).valueOrNull;
  if (profile == null) return const [];
  return coachFrameMissing(profile, ref.watch(currentTrainingGoalProvider));
});
