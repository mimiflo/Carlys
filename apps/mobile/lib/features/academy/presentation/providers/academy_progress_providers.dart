import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/academy_journey.dart';
import '../../domain/academy_progress.dart';
import '../controllers/academy_controllers.dart';

/// L'avancement dans le pack, croisé depuis les deux sources existantes.
///
/// Dérivé et sans état propre, donc `providers/` et non `controllers/` —
/// c'est la règle du dépôt, et `academy_controllers.dart` ne porte déjà
/// aucun Notifier.
///
/// Rend `null` tant que le pack n'est pas lu : un avancement de « 0 sur 0 »
/// pendant le chargement se lirait comme un pack vide.
final academyProgressProvider = Provider<AcademyProgress?>((ref) {
  final lessons = ref.watch(academyPackProvider).valueOrNull;
  if (lessons == null) {
    return null;
  }
  final answered = ref.watch(answeredLessonsProvider).valueOrNull ?? const {};
  return computeAcademyProgress(
    lessons: lessons,
    answeredIds: answered.keys.toSet(),
  );
});

/// L'avancement du Parcours, dérivé des MÊMES réponses que le reste de
/// l'Academy : une leçon lue hors parcours y compte aussi, la donnée est
/// unique. `null` tant que le pack n'est pas lu, comme l'avancement.
final academyJourneyProgressProvider = Provider<JourneyProgress?>((ref) {
  final lessons = ref.watch(academyPackProvider).valueOrNull;
  if (lessons == null) {
    return null;
  }
  final answered = ref.watch(answeredLessonsProvider).valueOrNull ?? const {};
  return computeJourneyProgress(
    stages: academyJourney,
    packIds: lessons.map((lesson) => lesson.id).toSet(),
    answeredIds: answered.keys.toSet(),
  );
});

/// Nombre de domaines entièrement abordés.
///
/// Sert le moteur de récompenses, qui ne connaît QUE cet entier : lui passer
/// l'énumération des domaines ferait dépendre la progression de l'Academy,
/// alors qu'un compte suffit à décider d'un palier.
final completedAcademyDomainsProvider = Provider<int>((ref) {
  return ref.watch(academyProgressProvider)?.domainesTermines.length ?? 0;
});
