import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Reporte l'état de synchronisation d'une opération sur l'entité locale
/// qu'elle concerne (`pending` | `synced` | `failed` | `conflict`) : c'est
/// cet état que les écrans affichent, la file elle-même reste invisible.
class SyncEntityMarker {
  const SyncEntityMarker(this._db);

  final AppDatabase _db;

  Future<void> mark(SyncOperation operation, String syncStatus) async {
    switch (operation.entityType) {
      case 'session':
        await (_db.update(
          _db.localWorkoutSessions,
        )..where((session) => session.id.equals(operation.entityId))).write(
          LocalWorkoutSessionsCompanion(syncStatus: Value(syncStatus)),
        );
      case 'set':
        await (_db.update(_db.localWorkoutSets)
              ..where((set) => set.id.equals(operation.entityId)))
            .write(LocalWorkoutSetsCompanion(syncStatus: Value(syncStatus)));
      case 'template':
        await (_db.update(
          _db.localWorkoutTemplates,
        )..where((template) => template.id.equals(operation.entityId))).write(
          LocalWorkoutTemplatesCompanion(syncStatus: Value(syncStatus)),
        );
    }
    await _markPlanItems(operation, syncStatus);
  }

  /// Le plan n'a pas d'opération à lui seul : il voyage AVEC autre chose.
  /// L'acquittement suit donc le transporteur — la création de séance pour le
  /// plan entier, la série pour son appariement, et `plan.skip` pour les
  /// prévisions passées.
  Future<void> _markPlanItems(
    SyncOperation operation,
    String syncStatus,
  ) async {
    final update = _db.update(_db.localSessionPlanItems);
    final value = LocalSessionPlanItemsCompanion(syncStatus: Value(syncStatus));

    switch (operation.operationType) {
      case 'session.create':
        await (update
              ..where((item) => item.sessionId.equals(operation.entityId)))
            .write(value);
      case 'plan.skip':
        final ids = _planItemIdsOf(operation);
        if (ids.isNotEmpty) {
          await (update..where((item) => item.id.isIn(ids))).write(value);
        }
      case 'set.upsert':
        final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
        final body = payload['body'] as Map<String, dynamic>;
        final planItemId = body['planItemId'] as String?;
        if (planItemId != null) {
          await (update..where((item) => item.id.equals(planItemId))).write(
            value,
          );
        }
    }
  }

  List<String> _planItemIdsOf(SyncOperation operation) {
    final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
    final body = payload['body'] as Map<String, dynamic>;
    return (body['planItemIds'] as List<dynamic>).cast<String>();
  }
}
