import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/synchronization/sync_owner.dart';
import '../../domain/entities/workout.dart';

/// Écritures locales d'une séance, **composables dans une transaction Drift**.
///
/// Raison d'être : le démarrage d'une séance a plusieurs appelants — le
/// repository de séances (`startWorkout`), le lancement d'un modèle
/// (`WorkoutTemplateRepositoryImpl.startFromTemplate`) et l'acceptation d'une
/// proposition du coach, qui doivent écrire la séance, le plan et l'opération
/// de synchronisation dans **une seule** transaction. Centraliser ici évite
/// d'avoir plusieurs versions de la règle « au plus une séance en cours », du
/// format de la ligne locale, du corps de `session.create` et du
/// propriétaire posé sur chaque opération.
///
/// Aucune méthode ne notifie le moteur de synchronisation : c'est à l'appelant
/// de le faire **après le commit** — un drainage déclenché à l'intérieur d'une
/// transaction s'exécuterait sur un exécuteur refermé entre-temps.
class WorkoutSessionWriter {
  const WorkoutSessionWriter({
    required AppDatabase database,
    required this._uuid,
    this._owner,
  }) : _db = database;

  final AppDatabase _db;
  final Uuid _uuid;

  /// Propriétaire posé sur chaque opération enfilée. Absent (tests hors
  /// ligne, démonstration), l'opération part sous le compte connecté au
  /// moment du drainage, comme les opérations héritées d'avant la colonne.
  final SyncOwnerResolver? _owner;

  /// Lève un [StateError] si une séance est déjà en cours.
  ///
  /// Le domaine impose **au plus une séance active** : deux séances
  /// simultanées rendraient l'écran de séance et l'appariement au plan
  /// ambigus.
  ///
  /// Appelée par [insertSession], donc DANS la transaction du démarrage :
  /// vérifiée avant de l'ouvrir, deux démarrages concurrents (double-touche,
  /// accueil + proposition du coach) passaient tous deux le SELECT puis
  /// inséraient chacun leur séance — la même course que la position des
  /// séries, corrigée de la même façon (voir [insertSet]).
  Future<void> requireNoActiveSession() async {
    final active =
        await (_db.select(_db.localWorkoutSessions)..where(
              (session) =>
                  session.status.equals(WorkoutStatus.inProgress.apiValue),
            ))
            .get();
    if (active.isNotEmpty) {
      throw StateError('Une séance est déjà en cours.');
    }
  }

  /// Écrit la séance et enfile `session.create`, dans la transaction courante.
  ///
  /// [templateId] et [templateName] sont transmis tels quels au serveur : si
  /// le modèle lui est inconnu (opération `template.save` encore en file ou
  /// définitivement refusée), il ignore l'identifiant et conserve le nom —
  /// **aucune séance n'est jamais perdue à cause d'un modèle**.
  ///
  /// [plan] est la copie aplatie du modèle, transmise EN BLOC avec la séance :
  /// c'est ce qui permet de reprendre la séance sur un autre appareil, avec
  /// ses cibles. Elle ne repart jamais ensuite — le plan est figé au
  /// lancement.
  Future<void> insertSession({
    required String id,
    required DateTime startedAt,
    String? name,
    String? templateId,
    String? templateName,
    List<Map<String, dynamic>> plan = const [],
  }) async {
    // La règle « au plus une séance active » se vérifie ICI, dans la
    // transaction : les transactions Drift se sérialisent, le perdant d'une
    // course voit donc la séance du gagnant et lève — `currentOrStart`
    // rattrape ce StateError et rejoint la séance apparue.
    await requireNoActiveSession();
    await _db
        .into(_db.localWorkoutSessions)
        .insert(
          LocalWorkoutSessionsCompanion.insert(
            id: id,
            name: Value(name),
            status: WorkoutStatus.inProgress.apiValue,
            startedAt: startedAt,
            templateId: Value(templateId),
            templateName: Value(templateName),
          ),
        );
    await enqueue(
      entityType: 'session',
      entityId: id,
      operationType: 'session.create',
      payload: {
        'id': id,
        if (name != null) 'name': name,
        'startedAt': startedAt.toIso8601String(),
        if (templateId != null) 'templateId': templateId,
        if (templateName != null) 'templateName': templateName,
        if (plan.isNotEmpty) 'plan': plan,
      },
    );
  }

  /// Écrit une série et enfile `set.upsert`, dans la transaction courante.
  ///
  /// Deux appelants : `WorkoutRepositoryImpl.addSet` (série libre) et
  /// `WorkoutTemplateRepositoryImpl.recordSetFulfillingPlan` (série qui honore
  /// une prévision du plan). Le second enchaîne, DANS LA MÊME TRANSACTION, le
  /// pointage de l'item de plan : sans cela, une application tuée entre les
  /// deux écritures laissait la série enregistrée et la case du plan vide.
  ///
  /// La POSITION se compte ici, donc à l'intérieur de la transaction. Elle se
  /// lisait auparavant avant de l'ouvrir : deux séries validées coup sur coup
  /// pouvaient lire le même compte et réclamer la même position.
  Future<void> insertSet({
    required String id,
    required AddSetInput input,
    required DateTime completedAt,
  }) async {
    final existing = await (_db.select(
      _db.localWorkoutSets,
    )..where((set) => set.sessionId.equals(input.sessionId))).get();
    final position = existing.length;

    await _db
        .into(_db.localWorkoutSets)
        .insert(
          LocalWorkoutSetsCompanion.insert(
            id: id,
            sessionId: input.sessionId,
            exerciseId: Value(input.exerciseId),
            exerciseName: input.exerciseName,
            position: position,
            kind: Value(input.kind.apiValue),
            reps: Value(input.reps),
            weightKg: Value(input.weightKg),
            durationSeconds: Value(input.durationSeconds),
            distanceMeters: Value(input.distanceMeters),
            restSeconds: Value(input.restSeconds),
            rpe: Value(input.rpe),
            plannedReps: Value(input.plannedReps),
            plannedWeightKg: Value(input.plannedWeightKg),
            completedAt: completedAt,
          ),
        );
    await enqueue(
      entityType: 'set',
      entityId: id,
      operationType: 'set.upsert',
      payload: {
        'sessionId': input.sessionId,
        'body': <String, dynamic>{
          'id': id,
          if (input.exerciseId != null) 'exerciseId': input.exerciseId,
          'exerciseName': input.exerciseName,
          'position': position,
          'kind': input.kind.apiValue,
          if (input.reps != null) 'reps': input.reps,
          if (input.weightKg != null) 'weightKg': input.weightKg,
          if (input.durationSeconds != null)
            'durationSeconds': input.durationSeconds,
          if (input.distanceMeters != null)
            'distanceMeters': input.distanceMeters,
          if (input.restSeconds != null) 'restSeconds': input.restSeconds,
          if (input.rpe != null) 'rpe': input.rpe,
          if (input.plannedReps != null) 'plannedReps': input.plannedReps,
          if (input.plannedWeightKg != null)
            'plannedWeightKg': input.plannedWeightKg,
          // L'appariement au plan voyage AVEC la série : aucune opération
          // supplémentaire, et l'ordre FIFO garantit que le serveur connaît
          // déjà le plan (transmis avec la création de la séance).
          if (input.planItemId != null) 'planItemId': input.planItemId,
          'completedAt': completedAt.toIso8601String(),
        },
      },
    );
  }

  /// Clôt la séance et enfile l'opération de clôture, dans la transaction
  /// courante. La DÉCISION de clore (séance trouvée, encore en cours) et le
  /// calcul de la durée restent à l'appelant : ici, on écrit.
  Future<void> closeSession({
    required String sessionId,
    required WorkoutStatus to,
    required String operationType,
    required DateTime endedAt,
    required int durationSeconds,
  }) async {
    await (_db.update(
      _db.localWorkoutSessions,
    )..where((row) => row.id.equals(sessionId))).write(
      LocalWorkoutSessionsCompanion(
        status: Value(to.apiValue),
        endedAt: Value(endedAt),
        durationSeconds: Value(durationSeconds),
        syncStatus: const Value('pending'),
      ),
    );
    await enqueue(
      entityType: 'session',
      entityId: sessionId,
      operationType: operationType,
      payload: {
        'id': sessionId,
        'body': {
          'endedAt': endedAt.toIso8601String(),
          'durationSeconds': durationSeconds,
        },
      },
    );
  }

  /// Corrige une série DÉJÀ enregistrée, localement puis en file.
  ///
  /// La correction est un PATCH, pas un réenregistrement : l'ajout d'une
  /// série est un upsert idempotent par identifiant, donc rejoué avec le même
  /// UUID il rend la série existante SANS la modifier.
  ///
  /// Le corps ne porte que ce qui change, et jamais `plannedReps` ni
  /// `plannedWeightKg` : la cible affichée à l'instant de la validation est un
  /// fait historique, que le serveur refuse d'ailleurs de réécrire.
  ///
  /// Une série inconnue ou déjà supprimée ne met RIEN en file : corriger ce
  /// qui n'existe plus enverrait un PATCH voué au 404, et la file ne rejoue
  /// jamais indéfiniment un refus définitif.
  Future<void> correctSet(
    String setId, {
    required int? reps,
    required double? weightKg,
  }) async {
    if (reps == null && weightKg == null) {
      return;
    }
    await _db.transaction(() async {
      final set = await (_db.select(
        _db.localWorkoutSets,
      )..where((row) => row.id.equals(setId))).getSingleOrNull();
      if (set == null || set.deleted) {
        return;
      }
      await (_db.update(
        _db.localWorkoutSets,
      )..where((row) => row.id.equals(setId))).write(
        LocalWorkoutSetsCompanion(
          reps: reps == null ? const Value.absent() : Value(reps),
          weightKg: weightKg == null ? const Value.absent() : Value(weightKg),
          // `pending` comme pour la pierre tombale : sans cela, le
          // rapatriement effacerait la correction locale en reproduisant
          // l'état du serveur, qui ne l'a pas encore reçue.
          syncStatus: const Value('pending'),
        ),
      );
      await enqueue(
        entityType: 'set',
        entityId: setId,
        operationType: 'set.update',
        // `sessionId` range l'opération sur la voie de sa séance, derrière la
        // création et l'ajout de la série : un PATCH parti avant son POST
        // serait refusé pour toujours.
        payload: {
          'sessionId': set.sessionId,
          'body': <String, dynamic>{
            if (reps != null) 'reps': reps,
            if (weightKg != null) 'weightKg': weightKg,
          },
        },
      );
    });
  }

  /// Insère une opération dans la file, dans la transaction courante.
  ///
  /// `idempotencyKey = entityId` : l'UUID métier généré sur l'appareil EST la
  /// clé d'idempotence côté serveur. `ownerUserId` : le compte connecté au
  /// moment de l'écriture, seul compte sous lequel elle partira.
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    final ownerUserId = await _owner?.currentOwnerId();
    await _db
        .into(_db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operationType: operationType,
            payload: jsonEncode(payload),
            createdAt: DateTime.now().toUtc(),
            idempotencyKey: entityId,
            ownerUserId: Value(ownerUserId),
          ),
        );
  }
}
