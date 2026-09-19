import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/utilities/current_day.dart';
import '../../../community/data/repositories/community_repository_impl.dart';
import '../../../community/presentation/controllers/community_controllers.dart';
import '../../data/academy_pack.dart';
import '../../data/answered_lessons_store.dart';
import '../../domain/daily_lesson.dart';
import '../../domain/entities/academy.dart';

/// Le pack d'apprentissage, chargé une fois par processus.
final academyPackProvider = FutureProvider<List<Lesson>>((ref) {
  return loadAcademyPack();
});

/// La leçon du jour — déterministe : le jour de l'année parcourt le pack en
/// boucle. Tout le monde a la même question le même jour, et elle change
/// chaque matin sans aucun tirage aléatoire.
///
/// « Chaque matin » se TIENT grâce à [currentDayProvider] : ce provider n'est
/// pas auto-disposé et sa seule autre dépendance ne bouge plus une fois le
/// pack chargé, si bien qu'un `DateTime.now()` lu ici figeait la question au
/// lancement — une application restée résidente, cas normal sur mobile,
/// servait la même question des jours durant.
final dailyLessonProvider = Provider<Lesson?>((ref) {
  final lessons = ref.watch(academyPackProvider).valueOrNull;
  if (lessons == null || lessons.isEmpty) {
    return null;
  }
  // Un jour CIVIL, pas une durée écoulée : voir `dayOfYearIndex`, qui porte
  // la mesure du décalage provoqué par les changements d'heure.
  final dayOfYear = dayOfYearIndex(ref.watch(currentDayProvider));
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
        .reportQuizAnswer(
          lessonId: lessonId,
          correct: correct,
          choiceIndex: choiceIndex,
        );
  }

  static const _logger = AppLogger('AcademyActions');

  /// Ramène du serveur les réponses données sur un AUTRE appareil, en
  /// meilleur effort : hors ligne, rien ne se passe et rien n'échoue.
  ///
  /// Le magasin local reste la source première (« la première gagne » y est
  /// déjà la règle : une réponse locale n'est jamais réécrite), le serveur
  /// ne fait que COMBLER les trous. Une réponse d'avant la migration, sans
  /// choix retenu, est ignorée : afficher un choix inventé mentirait sur ce
  /// qui a été coché.
  Future<void> pullAnswers() async {
    try {
      final serveur = await _ref
          .read(communityRepositoryProvider)
          .fetchQuizAnswers();
      if (serveur.isEmpty) {
        return;
      }
      final store = _ref.read(answeredLessonsStoreProvider);
      final locales = await store.read();
      var comblees = false;
      for (final entry in serveur.entries) {
        final choix = entry.value;
        if (choix == null || locales.containsKey(entry.key)) {
          continue;
        }
        await store.markAnswered(entry.key, choix);
        comblees = true;
      }
      if (comblees) {
        _ref.invalidate(answeredLessonsProvider);
      }
    } on Exception catch (exception) {
      _logger.warning('Réponses serveur non relues : $exception');
    }
  }
}

final academyActionsProvider = Provider<AcademyActions>(AcademyActions.new);
