import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../academy/presentation/controllers/academy_controllers.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../domain/progression.dart';
import '../../domain/progression_engine.dart';
import '../../domain/progression_facts_builder.dart';

/// Le profil de progression, recalculé à chaque changement de l'historique.
///
/// `null` tant que l'historique local n'est pas lu : l'écran montre alors un
/// chargement, jamais un profil vide qui se remplirait sous les yeux de
/// l'utilisateur en lui faisant croire qu'il vient de gagner des points.
///
/// Le jour de référence est pris ICI, une fois, et passé au calcul. Le moteur
/// reste ainsi une fonction pure de ses entrées, testable au cas par cas.
final progressionProfileProvider = Provider<ProgressionProfile?>((ref) {
  final history = ref.watch(workoutHistoryProvider).valueOrNull;
  if (history == null) {
    return null;
  }

  // Les leçons abordées sont un BONUS de lecture : si le stockage local n'a
  // pas encore répondu, le profil s'affiche quand même et l'axe « Maîtrise »
  // se dit en attente. Bloquer tout le profil sur cette seule lecture serait
  // disproportionné.
  final answered = ref.watch(answeredLessonsProvider).valueOrNull;
  final pack = ref.watch(academyPackProvider).valueOrNull;

  return computeProgression(
    buildProgressionFacts(
      history: history,
      today: DateTime.now(),
      lessonsAnswered: answered?.length ?? 0,
      lessonsTotal: pack?.length ?? 0,
    ),
  );
});
