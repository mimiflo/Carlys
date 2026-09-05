/// Modèles de séance du MODE DÉMO — jeu d'exemple en mémoire.
///
/// EXCEPTION DOCUMENTÉE à la règle « pas de données codées en dur », déjà en
/// vigueur pour ce dossier : ce fichier ne sert que le flavor `demo`, dont la
/// raison d'être est de faire visiter l'app sans serveur ni compte. Les modes
/// `development` et production passent toujours par Drift et l'API.
///
/// Les exercices repris ici sont ceux de `demo_workouts.dart` : l'historique
/// et les modèles racontent la même histoire.
library;

import 'dart:async';

import '../features/workout_session/domain/entities/workout.dart';
import '../features/workout_session/domain/repositories/workout_repository.dart';
import '../features/workout_template/domain/entities/session_plan.dart';
import '../features/workout_template/domain/entities/workout_template.dart';
import '../features/workout_template/domain/repositories/workout_template_repository.dart';
import '../features/workout_template/domain/services/template_normalizer.dart';

/// (nom, exercices) — chaque exercice : (nom, séries prévues).
const List<(String, int, List<(String, List<(int, double, int)>)>)>
_demoTemplates = [
  (
    'Push force',
    55,
    [
      (
        'Développé couché',
        [(12, 40, 60), (8, 70, 120), (8, 70, 120), (6, 80, 150)],
      ),
      ('Développé militaire', [(10, 40, 90), (10, 42.5, 90)]),
      ('Dips', [(12, 0, 90), (10, 0, 90)]),
    ],
  ),
  (
    'Pull hypertrophie',
    60,
    [
      ('Rowing barre', [(12, 40, 60), (10, 70, 120), (10, 72.5, 120)]),
      ('Traction pronation', [(9, 0, 120), (7, 0, 120)]),
      ('Curl haltères', [(12, 14, 60), (12, 14, 60)]),
    ],
  ),
];

/// Jeu de modèles de démonstration, sous la forme d'entrées d'écriture
/// ordinaires : le dépôt les enregistre comme n'importe quelle saisie.
List<SaveTemplateInput> demoTemplateSeed() => [
  for (final (index, template) in _demoTemplates.indexed)
    SaveTemplateInput(
      id: 'demo-template-$index',
      name: template.$1,
      estimatedDurationMinutes: template.$2,
      exercises: [
        for (final (exerciseName, sets) in template.$3)
          TemplateExerciseInput(
            exerciseName: exerciseName,
            sets: [
              for (final (reps, weight, rest) in sets)
                PlannedSetInput(
                  targetReps: reps,
                  targetWeightKg: weight == 0 ? null : weight,
                  restSeconds: rest,
                ),
            ],
          ),
      ],
    ),
];

/// Dépôt de modèles en mémoire : liste pré-remplie, édition, suppression et
/// lancement pleinement fonctionnels, sans base ni réseau.
///
/// Le lancement délègue la création de la séance au dépôt de séances, comme
/// l'implémentation réelle délègue au domaine séance.
///
/// [seed] permet de choisir le contenu de départ ; par défaut c'est le jeu de
/// démonstration ([demoTemplateSeed]).
class DemoWorkoutTemplateRepository implements WorkoutTemplateRepository {
  DemoWorkoutTemplateRepository(
    this._workouts, {
    List<SaveTemplateInput>? seed,
  }) {
    for (final (index, input) in (seed ?? demoTemplateSeed()).indexed) {
      final detail = normalizeTemplateInput(
        input: input,
        newId: () => 'demo-${_nextId++}',
        updatedAt: DateTime.now().toUtc().subtract(Duration(days: index)),
        syncState: LocalSyncState.synced,
      );
      _templates[detail.id] = detail;
    }
  }

  final WorkoutRepository _workouts;
  final Map<String, WorkoutTemplateDetail> _templates = {};
  final Map<String, List<SessionPlanItem>> _plans = {};

  /// Nom du modèle au lancement, par séance — provenance dénormalisée.
  final Map<String, String> _planTemplateNames = {};
  final _templatesController =
      StreamController<List<WorkoutTemplateInfo>>.broadcast();
  final _plansController = StreamController<String>.broadcast();
  int _nextId = 0;

  List<WorkoutTemplateInfo> get _list {
    final infos = _templates.values.map((template) => template.info).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(infos);
  }

  @override
  Stream<List<WorkoutTemplateInfo>> watchTemplates() async* {
    yield _list;
    yield* _templatesController.stream;
  }

  @override
  Future<WorkoutTemplateDetail?> templateDetail(String templateId) async =>
      _templates[templateId];

  @override
  Future<String> saveTemplate(SaveTemplateInput input) async {
    final detail = normalizeTemplateInput(
      input: input,
      newId: () => 'demo-${_nextId++}',
      updatedAt: DateTime.now().toUtc(),
      lastUsedAt: _templates[input.id]?.info.lastUsedAt,
      syncState: LocalSyncState.synced,
    );
    _templates[detail.id] = detail;
    _templatesController.add(_list);
    return detail.id;
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    _templates.remove(templateId);
    _templatesController.add(_list);
  }

  @override
  Future<String> startFromTemplate(String templateId) async {
    final template = _templates[templateId];
    if (template == null) {
      throw StateError('Modèle de séance introuvable : $templateId');
    }
    final sessionId = await _workouts.startWorkout(
      name: template.name,
      templateId: template.id,
      templateName: template.name,
    );
    _planTemplateNames[sessionId] = template.name;
    _plans[sessionId] = [
      for (final exercise in template.exercises)
        for (final set in exercise.sets)
          SessionPlanItem(
            id: 'demo-plan-${_nextId++}',
            sessionId: sessionId,
            exercisePosition: exercise.position,
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.exerciseName,
            setPosition: set.position,
            kind: set.kind,
            targetReps: set.targetReps,
            targetWeightKg: set.targetWeightKg,
            restSeconds: set.restSeconds,
          ),
    ];
    _plansController.add(sessionId);
    return sessionId;
  }

  @override
  Stream<SessionPlan?> watchSessionPlan(String sessionId) async* {
    yield _planOf(sessionId);
    yield* _plansController.stream
        .where((changed) => changed == sessionId)
        .map((_) => _planOf(sessionId));
  }

  @override
  Future<SessionPlan?> sessionPlan(String sessionId) async =>
      _planOf(sessionId);

  SessionPlan? _planOf(String sessionId) {
    final items = _plans[sessionId];
    if (items == null || items.isEmpty) {
      return null;
    }
    return SessionPlan(
      sessionId: sessionId,
      templateName: _planTemplateNames[sessionId] ?? '',
      items: List.unmodifiable(items),
    );
  }

  /// Même règle d'appariement que l'implémentation réelle : elle vit sur
  /// l'entité [SessionPlan], jamais recopiée ici.
  @override
  Future<SessionPlanItem?> nextPlanItemFor({
    required String sessionId,
    required String exerciseName,
    String? exerciseId,
  }) async => _planOf(
    sessionId,
  )?.nextPendingFor(exerciseName: exerciseName, exerciseId: exerciseId);

  @override
  Future<void> fulfillPlanItem({
    required String planItemId,
    required String setId,
  }) async => _replace(planItemId, (item) => _copy(item, doneSetId: setId));

  @override
  Future<void> skipPlanItem(String planItemId) async =>
      _replace(planItemId, (item) => _copy(item, skipped: true));

  @override
  Future<void> skipPlanExercise({
    required String sessionId,
    required int exercisePosition,
  }) async {
    final items = _plans[sessionId];
    if (items == null) {
      return;
    }
    for (final (index, item) in items.indexed) {
      if (item.exercisePosition == exercisePosition && !item.isDone) {
        items[index] = _copy(item, skipped: true);
      }
    }
    _plansController.add(sessionId);
  }

  @override
  Future<void> purgeSessionPlan(String sessionId) async {
    _plans.remove(sessionId);
    _planTemplateNames.remove(sessionId);
    _plansController.add(sessionId);
  }

  /// Le mode démo n'a pas de serveur : il n'y a rien à rapatrier.
  @override
  Future<void> refreshTemplates() async {}

  void _replace(
    String planItemId,
    SessionPlanItem Function(SessionPlanItem) update,
  ) {
    for (final entry in _plans.entries) {
      final index = entry.value.indexWhere((item) => item.id == planItemId);
      if (index >= 0) {
        entry.value[index] = update(entry.value[index]);
        _plansController.add(entry.key);
        return;
      }
    }
  }

  SessionPlanItem _copy(
    SessionPlanItem item, {
    String? doneSetId,
    bool? skipped,
  }) {
    return SessionPlanItem(
      id: item.id,
      sessionId: item.sessionId,
      exercisePosition: item.exercisePosition,
      exerciseId: item.exerciseId,
      exerciseName: item.exerciseName,
      setPosition: item.setPosition,
      kind: item.kind,
      targetReps: item.targetReps,
      targetWeightKg: item.targetWeightKg,
      restSeconds: item.restSeconds,
      doneSetId: doneSetId ?? item.doneSetId,
      skipped: skipped ?? item.skipped,
    );
  }
}
