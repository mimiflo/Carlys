import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/synchronization/sync_engine.dart';
import '../../../workout_session/data/local/workout_session_writer.dart';
import '../../domain/entities/session_plan.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/repositories/workout_template_repository.dart';
import '../../domain/services/template_normalizer.dart';
import '../datasources/session_plan_local_data_source.dart';
import '../datasources/workout_template_local_data_source.dart';
import '../datasources/workout_template_remote_data_source.dart';
import '../dto/workout_template_dtos.dart';
import 'workout_template_downloader.dart';

/// Implémentation offline-first des modèles de séance.
///
/// Même discipline que les séances : Drift d'abord, opération de
/// synchronisation dans la **même transaction**, moteur notifié seulement
/// après le commit, lectures réactives depuis le local.
class WorkoutTemplateRepositoryImpl implements WorkoutTemplateRepository {
  WorkoutTemplateRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
    WorkoutTemplateRemoteDataSource? remote,
    Uuid uuid = const Uuid(),
  })  : _db = database,
        _sync = syncEngine,
        _remote = remote,
        _uuid = uuid,
        _local = WorkoutTemplateLocalDataSource(database),
        _plans = SessionPlanLocalDataSource(database),
        _sessions = WorkoutSessionWriter(database: database, uuid: uuid);

  final AppDatabase _db;
  final SyncEngine _sync;
  final WorkoutTemplateRemoteDataSource? _remote;
  final Uuid _uuid;
  final WorkoutTemplateLocalDataSource _local;
  final SessionPlanLocalDataSource _plans;

  /// Écritures de séance de la fonctionnalité `workout_session` : le lancement
  /// d'un modèle ne réimplémente ni la règle « au plus une séance en cours »,
  /// ni le format de la ligne locale, ni le corps de `session.create`.
  final WorkoutSessionWriter _sessions;

  // ── Lectures ─────────────────────────────────────────────────────────────

  @override
  Stream<List<WorkoutTemplateInfo>> watchTemplates() => _local
      .watchAll()
      .map((templates) => templates.map((it) => it.info).toList());

  @override
  Future<WorkoutTemplateDetail?> templateDetail(String templateId) =>
      _local.detail(templateId);

  @override
  Stream<SessionPlan?> watchSessionPlan(String sessionId) =>
      _plans.watchPlan(sessionId);

  @override
  Future<SessionPlan?> sessionPlan(String sessionId) => _plans.plan(sessionId);

  // ── Écritures ────────────────────────────────────────────────────────────

  @override
  Future<String> saveTemplate(SaveTemplateInput input) async {
    final now = DateTime.now().toUtc();
    // Validation AVANT toute écriture : un modèle hors bornes ne doit jamais
    // atteindre la file, où il finirait `failed` — c'est-à-dire perdu.
    final existing = input.id == null ? null : await _local.headerOf(input.id!);
    final template = normalizeTemplateInput(
      input: input,
      newId: _uuid.v4,
      updatedAt: now,
      lastUsedAt: existing?.lastUsedAt,
    );

    await _db.transaction(() async {
      await _local.upsertHeader(
        template: template,
        updatedAt: now,
        syncStatus: 'pending',
        lastUsedAt: existing?.lastUsedAt,
      );
      await _local.replaceContent(template);
      // Le `PUT` décrit l'état COMPLET : une sauvegarde encore en attente est
      // périmée dès qu'une nouvelle arrive. On la remplace au lieu d'empiler
      // N opérations pendant l'édition.
      await _dropPending(template.id, 'template.save');
      await _sessions.enqueue(
        entityType: 'template',
        entityId: template.id,
        operationType: 'template.save',
        payload: {'body': templatePutBody(template)},
      );
    });

    _poke();
    return template.id;
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    final existing = await _local.headerOf(templateId);
    if (existing == null || existing.deleted) {
      return; // rejeu sans effet : la suppression est idempotente côté client
    }

    await _db.transaction(() async {
      await _local.markDeleted(templateId);
      // Un enregistrement jamais parti n'a plus de destinataire : `DELETE` sur
      // un modèle inconnu du serveur répond 204, la file reste cohérente.
      await _dropPending(templateId, 'template.save');
      await _sessions.enqueue(
        entityType: 'template',
        entityId: templateId,
        operationType: 'template.delete',
        payload: {'id': templateId},
      );
    });

    _poke();
  }

  /// **Lancer un modèle** — la jointure entre le prescrit et le factuel.
  ///
  /// Trois écritures locales, une seule transaction :
  ///  1. la **séance** (`LocalWorkoutSessions`) est créée par
  ///     [WorkoutSessionWriter], donc exactement comme `startWorkout` le fait,
  ///     avec `templateId` + `templateName` dénormalisé : l'écran de séance
  ///     active, l'historique et le serveur voient une séance ordinaire ;
  ///  2. le **plan** (`LocalSessionPlanItems`) est la copie APLATIE du modèle,
  ///     une ligne par série prévue, dans l'ordre (exercice, série). C'est ce
  ///     que l'écran lit pour dire « série 2 sur 4, 8 reps à 60 kg » et pour
  ///     pré-remplir le pas-à-pas ;
  ///  3. l'opération **`session.create`** est enfilée par le même writer.
  ///
  /// Le plan est une **copie**, pas un lien vivant : modifier le modèle
  /// pendant la séance ne change rien à la séance en cours, et l'historique
  /// reste vrai (D1). Il reste purement local : le serveur ne reçoit que des
  /// faits (D5).
  ///
  /// Aucun appel réseau : lancer un modèle marche hors ligne, y compris au
  /// tout premier lancement. Si `template.save` n'est jamais partie, la séance
  /// part quand même — le serveur ignore alors le `templateId` et conserve le
  /// `templateName` transmis.
  @override
  Future<String> startFromTemplate(String templateId) async {
    final template = await _local.detail(templateId);
    if (template == null) {
      throw StateError('Modèle de séance introuvable : $templateId');
    }
    await _sessions.requireNoActiveSession();

    final sessionId = _uuid.v4();
    final startedAt = DateTime.now().toUtc();

    await _db.transaction(() async {
      await _sessions.insertSession(
        id: sessionId,
        name: template.name,
        startedAt: startedAt,
        templateId: template.id,
        templateName: template.name,
      );
      await _plans.insertPlanItems(_flattenPlan(sessionId, template));
      // Miroir local du `lastUsedAt` que le serveur posera à la création de la
      // séance : aucune opération de synchronisation, ce n'est pas une saisie.
      await _local.touchLastUsedAt(template.id, startedAt);
    });

    _poke();
    return sessionId;
  }

  /// Aplatit le modèle : une entrée de plan par série prévue.
  List<LocalSessionPlanItemsCompanion> _flattenPlan(
    String sessionId,
    WorkoutTemplateDetail template,
  ) {
    return [
      for (final exercise in template.exercises)
        for (final set in exercise.sets)
          LocalSessionPlanItemsCompanion.insert(
            id: _uuid.v4(),
            sessionId: sessionId,
            exercisePosition: exercise.position,
            exerciseId: Value(exercise.exerciseId),
            exerciseName: exercise.exerciseName,
            setPosition: set.position,
            kind: Value(set.kind.apiValue),
            targetReps: Value(set.targetReps),
            targetWeightKg: Value(set.targetWeightKg),
            restSeconds: Value(set.restSeconds),
          ),
    ];
  }

  // ── Appariement plan ↔ série réalisée ────────────────────────────────────

  /// Règle unique, déterministe : le **premier item de l'exercice concerné qui
  /// n'est ni fait ni sauté**. S'il n'y en a aucun (série supplémentaire ou
  /// exercice hors programme), aucun item n'est honoré — l'avancement ne
  /// dépasse donc jamais 100 % et une série en trop ne consomme pas une série
  /// prévue plus loin.
  @override
  Future<SessionPlanItem?> nextPlanItemFor({
    required String sessionId,
    required String exerciseName,
    String? exerciseId,
  }) async {
    final plan = await _plans.plan(sessionId);
    // La règle vit sur l'entité [SessionPlan] : l'écran de séance l'applique
    // à la même seconde pour ANNONCER la cible, le repository l'applique ici
    // pour l'HONORER. Une seule implémentation, donc jamais de désaccord
    // entre ce qui est affiché et ce qui est enregistré.
    return plan?.nextPendingFor(
      exerciseName: exerciseName,
      exerciseId: exerciseId,
    );
  }

  @override
  Future<void> fulfillPlanItem({
    required String planItemId,
    required String setId,
  }) =>
      _plans.fulfillItem(planItemId: planItemId, setId: setId);

  @override
  Future<void> skipPlanItem(String planItemId) => _plans.skipItem(planItemId);

  @override
  Future<void> skipPlanExercise({
    required String sessionId,
    required int exercisePosition,
  }) =>
      _plans.skipExercise(
        sessionId: sessionId,
        exercisePosition: exercisePosition,
      );

  @override
  Future<void> purgeSessionPlan(String sessionId) =>
      _plans.purgePlan(sessionId);

  // ── Rapatriement depuis le serveur ───────────────────────────────────────

  @override
  Future<void> refreshTemplates() async {
    final remote = _remote;
    if (remote == null) {
      return; // aucune source distante (mode démo, tests hors ligne)
    }
    await WorkoutTemplateDownloader(
      database: _db,
      local: _local,
      remote: remote,
    ).run();
  }

  // ── Interne ──────────────────────────────────────────────────────────────

  Future<void> _dropPending(String templateId, String operationType) {
    return (_db.delete(_db.syncOperations)
          ..where(
            (operation) =>
                operation.entityId.equals(templateId) &
                operation.operationType.equals(operationType) &
                operation.status.equals('pending'),
          ))
        .go();
  }

  /// Notifie le moteur, toujours **après le commit** : un drainage lancé dans
  /// la transaction s'exécuterait sur un exécuteur refermé entre-temps.
  void _poke() {
    unawaited(_sync.syncNow());
  }
}

final workoutTemplateRepositoryProvider =
    Provider<WorkoutTemplateRepository>((ref) {
  return WorkoutTemplateRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    syncEngine: ref.watch(syncEngineProvider),
    remote: ref.watch(workoutTemplateRemoteDataSourceProvider),
  );
});
