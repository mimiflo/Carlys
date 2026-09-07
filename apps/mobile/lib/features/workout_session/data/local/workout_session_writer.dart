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
