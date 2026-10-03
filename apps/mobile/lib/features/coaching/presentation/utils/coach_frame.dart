import '../../../workout_program/domain/entities/training_goal.dart';
import '../../../workout_program/domain/entities/training_profile.dart';

/// Ce qui manque au coach pour composer à coup sûr : ton objectif, ton
/// niveau, ton matériel — dans l'ordre où il le dit. Vide : il a tout.
///
/// Une seule règle, pour la carte « Avant de commencer » du fil comme pour
/// l'envoi, qui DEMANDE ce qui manque avant que le coach ne réfléchisse.
List<String> coachFrameMissing(TrainingProfile profile, TrainingGoal? goal) => [
  if (goal == null) 'ton objectif',
  if (profile.experience == null) 'ton niveau',
  if (profile.equipmentSlugs.isEmpty) 'ton matériel',
];

/// « ton objectif, ton niveau et ton matériel ».
String coachFrameList(List<String> items) => items.length == 1
    ? items.single
    : '${items.take(items.length - 1).join(', ')} et ${items.last}';
