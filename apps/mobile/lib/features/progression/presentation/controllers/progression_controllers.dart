import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../academy/presentation/controllers/academy_controllers.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
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
/// L'historique local n'a pas pu être lu DU TOUT.
///
/// Le flux vient de Drift : ce n'est pas une panne de réseau mais une base
/// illisible, donc rare. Il faut néanmoins le dire, sinon l'écran tourne
/// indéfiniment sur son indicateur de chargement et laisse croire à un calcul
/// interminable.
///
/// La condition porte les DEUX termes : un flux qui échoue après avoir déjà
/// émis conserve sa dernière valeur, et un profil réel vaut mieux qu'un écran
/// d'erreur pour une émission perdue en route.
final progressionUnreadableProvider = Provider<bool>((ref) {
  final history = ref.watch(workoutHistoryProvider);
  return history.hasError && !history.hasValue;
});

/// L'initiale portée par l'avatar du profil.
///
/// Isolée dans son propre fournisseur pour une raison précise : le profil de
/// progression se dérive de faits LOCAUX et doit s'afficher entier sans
/// session lue. Brancher l'écran directement sur la session le rendrait
/// dépendant d'une chaîne qu'il n'utilise que pour une lettre.
///
/// Une lettre par défaut plutôt qu'un trou : un avatar vide se lirait comme
/// un chargement qui n'aboutit pas.
final progressionInitialProvider = Provider<String>((ref) {
  final user = switch (ref.watch(authControllerProvider)) {
    AuthAuthenticated(:final user) => user,
    _ => null,
  };
  final name = user?.displayName.trim() ?? '';
  return name.isEmpty
      ? 'C'
      : String.fromCharCode(name.runes.first).toUpperCase();
});

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
