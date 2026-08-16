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

/// Les questions déjà abordées, et le choix retenu pour chacune.
///
/// Non auto-disposé, et c'est ce qui fait tenir la fonctionnalité : l'accueil
/// et l'Academy montrent la MÊME question du jour, et ils lisent tous deux
/// cette carte-là. Répondre d'un côté la remplit de l'autre. Le profil de
/// progression s'en sert aussi, et le relire à chaque navigation ferait
/// clignoter l'axe « Maîtrise » à chaque aller-retour.
final answeredLessonsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.read(answeredLessonsStoreProvider).read();
});

/// Ce que l'Academy sait faire en écriture.
class AcademyActions {
  const AcademyActions(this._ref);

  final Ref _ref;

  /// Enregistre une réponse à une question.
  ///
  /// Deux destinations, dans cet ordre volontaire. La marque LOCALE d'abord :
  /// c'est elle qui remplit la carte à l'autre endroit où la question
  /// apparaît, et qui nourrit l'axe « Maîtrise » ; elle doit tenir hors
  /// ligne. Le rapport au serveur ensuite, pour les défis culturels, en
  /// meilleur effort : il avale déjà ses propres erreurs, et une panne de
  /// réseau ne doit pas faire perdre la trace d'une question abordée.
  ///
  /// La bonne comme la mauvaise réponse comptent : se tromper fait
  /// apprendre, et n'ouvrir l'axe qu'aux bonnes réponses transformerait
  /// l'Academy en examen.
  Future<void> answer({
    required String lessonId,
    required int choiceIndex,
    required bool correct,
  }) async {
    await _ref
        .read(answeredLessonsStoreProvider)
        .markAnswered(lessonId, choiceIndex);
    _ref.invalidate(answeredLessonsProvider);
    await _ref
        .read(communityActionsProvider)
        .reportQuizAnswer(lessonId: lessonId, correct: correct);
  }
}

final academyActionsProvider = Provider<AcademyActions>(AcademyActions.new);
