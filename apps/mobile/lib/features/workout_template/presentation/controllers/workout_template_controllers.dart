/// Providers des modèles de séance — **seule porte d'entrée des écrans**.
///
/// Aucun widget n'appelle l'API ni Drift : écran → contrôleur → repository.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../workout_session/data/repositories/workout_repository_impl.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../data/repositories/workout_template_repository_impl.dart';
import '../../domain/entities/session_plan.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/repositories/workout_template_repository.dart';
import '../../domain/usecases/record_planned_set.dart';

/// Liste des modèles, plus récemment modifiés d'abord, en temps réel depuis la
/// base locale — donc disponible hors ligne, sans état d'erreur réseau.
final workoutTemplatesProvider = StreamProvider<List<WorkoutTemplateInfo>>((
  ref,
) {
  return ref.watch(workoutTemplateRepositoryProvider).watchTemplates();
});

/// Contenu complet d'un modèle. `null` quand il n'existe pas (encore) : c'est
/// le cas normal d'une **création**, l'éditeur part alors d'un brouillon vide.
final workoutTemplateDetailProvider = FutureProvider.autoDispose
    .family<WorkoutTemplateDetail?, String>((ref, templateId) {
      return ref
          .watch(workoutTemplateRepositoryProvider)
          .templateDetail(templateId);
    });

/// Plan de la séance en cours, en temps réel. `null` = séance libre : l'écran
/// de séance garde exactement son comportement actuel.
final sessionPlanProvider = StreamProvider.autoDispose
    .family<SessionPlan?, String>((ref, sessionId) {
      return ref
          .watch(workoutTemplateRepositoryProvider)
          .watchSessionPlan(sessionId);
    });

/// Cas d'usage « valider une série en l'appariant au plan ».
final recordPlannedSetProvider = Provider<RecordPlannedSet>((ref) {
  return RecordPlannedSet(
    workouts: ref.watch(workoutRepositoryProvider),
    templates: ref.watch(workoutTemplateRepositoryProvider),
  );
});

/// Actions des modèles de séance.
///
/// Toutes écrivent d'abord en local : elles rendent la main immédiatement,
/// hors ligne comme en ligne, et ne lèvent jamais d'erreur réseau.
class WorkoutTemplateActions {
  const WorkoutTemplateActions(this._ref);

  final Ref _ref;

  WorkoutTemplateRepository get _repository =>
      _ref.read(workoutTemplateRepositoryProvider);

  /// Identifiant d'un **nouveau** modèle, généré sur l'appareil avant toute
  /// écriture : c'est ce qui permet d'ouvrir `/templates/<uuid>` hors ligne,
  /// sans route `/templates/new` ni identifiant attribué par le serveur.
  ///
  /// Passe par le contrôleur, jamais par un widget : un écran ne fabrique pas
  /// d'identifiant lui-même.
  String newTemplateId() => const Uuid().v4();

  /// Crée ou remplace un modèle et renvoie son identifiant.
  ///
  /// Lève [InvalidTemplateException] si la saisie sort des bornes — message
  /// déjà rédigé en français, affichable tel quel.
  Future<String> save(SaveTemplateInput input) =>
      _repository.saveTemplate(input);

  Future<void> delete(String templateId) =>
      _repository.deleteTemplate(templateId);

  /// Lance le modèle : crée la séance et matérialise son plan. Renvoie l'id de
  /// la séance à afficher. Lève un [StateError] si une séance est déjà en
  /// cours (l'écran propose alors de la terminer d'abord).
  Future<String> start(String templateId) =>
      _repository.startFromTemplate(templateId);

  /// Valide une série : appariement au plan, écriture locale, mise en file.
  Future<RecordedSet> recordSet(AddSetInput input) =>
      _ref.read(recordPlannedSetProvider)(input);

  Future<void> skipSet(String planItemId) =>
      _repository.skipPlanItem(planItemId);

  Future<void> skipExercise({
    required String sessionId,
    required int exercisePosition,
  }) => _repository.skipPlanExercise(
    sessionId: sessionId,
    exercisePosition: exercisePosition,
  );

  /// Purge le plan local d'une séance close (rien n'a jamais été envoyé).
  Future<void> purgePlan(String sessionId) =>
      _repository.purgeSessionPlan(sessionId);

  /// Rapatrie les modèles du serveur (réinstallation, nouvel appareil).
  Future<void> refresh() => _repository.refreshTemplates();
}

final workoutTemplateActionsProvider = Provider<WorkoutTemplateActions>(
  WorkoutTemplateActions.new,
);
