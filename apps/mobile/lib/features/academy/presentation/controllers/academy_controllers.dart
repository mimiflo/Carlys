import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../community/presentation/controllers/community_controllers.dart';
import '../../data/academy_pack.dart';
import '../../data/answered_lessons_store.dart';
import '../../domain/entities/academy.dart';

/// Le pack d'apprentissage, chargé une fois par processus.
final academyPackProvider = FutureProvider<List<Lesson>>((ref) {
  return loadAcademyPack();
});

/// La leçon du jour — déterministe : le jour de l'année parcourt le pack en
/// boucle. Tout le monde a la même question le même jour, et elle change
/// chaque matin sans aucun tirage aléatoire.
final dailyLessonProvider = Provider<Lesson?>((ref) {
  final lessons = ref.watch(academyPackProvider).valueOrNull;
  if (lessons == null || lessons.isEmpty) {
    return null;
  }
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  return lessons[dayOfYear % lessons.length];
});

/// Les leçons déjà abordées, lues sur l'appareil.
///
/// Non auto-disposé : le profil de progression et l'Academy le lisent tous
/// les deux, et le relire à chaque navigation ferait clignoter l'axe
/// « Maîtrise » à chaque aller-retour.
final answeredLessonsProvider = FutureProvider<Set<String>>((ref) {
  return ref.read(answeredLessonsStoreProvider).read();
});

/// Ce que l'Academy sait faire en écriture.
class AcademyActions {
  const AcademyActions(this._ref);

  final Ref _ref;

  /// Enregistre une réponse à une question.
  ///
  /// Deux destinations, dans cet ordre volontaire. La marque LOCALE d'abord :
  /// elle est la source de l'axe « Maîtrise » et doit tenir hors ligne. Le
  /// rapport au serveur ensuite, pour les défis culturels, en meilleur effort
  /// — il avale déjà ses propres erreurs, une panne de réseau ne doit pas
  /// faire perdre la trace d'une leçon apprise.
  ///
  /// La bonne comme la mauvaise réponse comptent : se tromper fait
  /// apprendre, et n'ouvrir l'axe qu'aux bonnes réponses transformerait
  /// l'Academy en examen.
  Future<void> answer({
    required String lessonId,
    required bool correct,
  }) async {
    await _ref.read(answeredLessonsStoreProvider).markAnswered(lessonId);
    _ref.invalidate(answeredLessonsProvider);
    await _ref
        .read(communityActionsProvider)
        .reportQuizAnswer(lessonId: lessonId, correct: correct);
  }
}

final academyActionsProvider = Provider<AcademyActions>(AcademyActions.new);
