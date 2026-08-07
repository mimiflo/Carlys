import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Séance locale — source de vérité immédiate de l'application.
class LocalWorkoutSessions extends Table {
  /// UUID généré sur l'appareil, partagé avec le serveur.
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// IN_PROGRESS | COMPLETED | ABANDONED (valeurs API).
  TextColumn get status => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  /// pending | synced | failed.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Série locale (append-only : jamais perdue, suppression logique).
class LocalWorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get exerciseId => text().nullable()();
  TextColumn get exerciseName => text()();
  IntColumn get position => integer()();

  /// WARMUP | NORMAL | DROP (valeurs API).
  TextColumn get kind => text().withDefault(const Constant('NORMAL'))();
  IntColumn get reps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  IntColumn get rpe => integer().nullable()();
  DateTimeColumn get completedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// File d'opérations de synchronisation (docs/synchronization/offline-first.md).
class SyncOperations extends Table {
  TextColumn get id => text()();

  /// session | set.
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// session.create | session.complete | session.abandon | set.upsert | set.delete.
  TextColumn get operationType => text()();

  /// Corps JSON de la requête à rejouer.
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// pending | failed (une opération réussie est supprimée).
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get error => text().nullable()();

  /// L'id de l'entité EST la clé d'idempotence côté serveur.
  TextColumn get idempotencyKey => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalWorkoutSessions, LocalWorkoutSets, SyncOperations])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// Connexion sur fichier, ouverte paresseusement dans un isolate dédié.
QueryExecutor openAppDatabaseConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(
      File(p.join(directory.path, 'carlys.sqlite')),
    );
  });
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(openAppDatabaseConnection());
  ref.onDispose(database.close);
  return database;
});
