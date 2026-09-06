/// Schémas locaux TELS QU'ILS ONT EXISTÉ, version par version.
///
/// Les tests de migration partent d'une base réellement créée avec le schéma
/// d'alors, puis laissent `AppDatabase` la monter jusqu'à la version courante :
/// c'est le seul moyen d'exercer chaque branche de `onUpgrade` sur des
/// données qui existaient vraiment. Drift n'exporte pas ces anciens schémas,
/// ils sont donc recopiés ici, colonne par colonne, depuis l'historique des
/// définitions de `app_database.dart`.
library;

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:drift/native.dart';

/// Un schéma historique : son numéro et le DDL qui le crée.
class LegacySchema {
  const LegacySchema(this.version, this.statements);

  final int version;
  final List<String> statements;
}

/// Ouvre une base en mémoire créée avec [schema], remplie par [seed], et
/// marquée à sa version : la première requête déclenchera `onUpgrade`.
AppDatabase openLegacyDatabase(
  LegacySchema schema, {
  List<String> seed = const [],
}) {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        for (final statement in [
          ...schema.statements,
          ...seed,
          'PRAGMA user_version = ${schema.version};',
        ]) {
          raw.execute(statement);
        }
      },
    ),
  );
}

// ── Tables, dans la forme de chaque époque ──────────────────────────────────

const String _sessionsV1 = '''
CREATE TABLE local_workout_sessions (
  id TEXT NOT NULL,
  name TEXT NULL,
  notes TEXT NULL,
  status TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NULL,
  duration_seconds INTEGER NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  PRIMARY KEY (id)
);
''';

/// Version 2 : `template_id` et `template_name` (provenance d'un modèle).
const String _sessionsV2 = '''
CREATE TABLE local_workout_sessions (
  id TEXT NOT NULL,
  name TEXT NULL,
  notes TEXT NULL,
  status TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  ended_at INTEGER NULL,
  duration_seconds INTEGER NULL,
  template_id TEXT NULL,
  template_name TEXT NULL,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  PRIMARY KEY (id)
);
''';

const String _setsV1 = '''
CREATE TABLE local_workout_sets (
  id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  exercise_id TEXT NULL,
  exercise_name TEXT NOT NULL,
  position INTEGER NOT NULL,
  kind TEXT NOT NULL DEFAULT 'NORMAL',
  reps INTEGER NULL,
  weight_kg REAL NULL,
  duration_seconds INTEGER NULL,
  rest_seconds INTEGER NULL,
  rpe INTEGER NULL,
  completed_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  PRIMARY KEY (id)
);
''';

/// Version 2 : `planned_reps` et `planned_weight_kg` (cible affichée).
const String _setsV2 = '''
CREATE TABLE local_workout_sets (
  id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  exercise_id TEXT NULL,
  exercise_name TEXT NOT NULL,
  position INTEGER NOT NULL,
  kind TEXT NOT NULL DEFAULT 'NORMAL',
  reps INTEGER NULL,
  weight_kg REAL NULL,
  duration_seconds INTEGER NULL,
  rest_seconds INTEGER NULL,
  rpe INTEGER NULL,
  planned_reps INTEGER NULL,
  planned_weight_kg REAL NULL,
  completed_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  PRIMARY KEY (id)
);
''';

const String _syncOperationsV1 = '''
CREATE TABLE sync_operations (
  id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_attempt_at INTEGER NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  error TEXT NULL,
  idempotency_key TEXT NOT NULL,
  PRIMARY KEY (id)
);
''';

const String _templatesV2 = '''
CREATE TABLE local_workout_templates (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  notes TEXT NULL,
  estimated_duration_minutes INTEGER NULL,
  last_used_at INTEGER NULL,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  PRIMARY KEY (id)
);
''';

const String _templateExercisesV2 = '''
CREATE TABLE local_template_exercises (
  id TEXT NOT NULL,
  template_id TEXT NOT NULL,
  exercise_id TEXT NULL,
  exercise_name TEXT NOT NULL,
  position INTEGER NOT NULL,
  notes TEXT NULL,
  PRIMARY KEY (id)
);
''';

const String _templateSetsV2 = '''
CREATE TABLE local_template_sets (
  id TEXT NOT NULL,
  template_exercise_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  kind TEXT NOT NULL DEFAULT 'NORMAL',
  target_reps INTEGER NULL,
  target_weight_kg REAL NULL,
  rest_seconds INTEGER NULL,
  PRIMARY KEY (id)
);
''';

/// Version 2 : le plan n'était pas encore synchronisable — pas de
/// `sync_status`.
const String _planItemsV2 = '''
CREATE TABLE local_session_plan_items (
  id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  exercise_position INTEGER NOT NULL,
  exercise_id TEXT NULL,
  exercise_name TEXT NOT NULL,
  set_position INTEGER NOT NULL,
  kind TEXT NOT NULL DEFAULT 'NORMAL',
  target_reps INTEGER NULL,
  target_weight_kg REAL NULL,
  rest_seconds INTEGER NULL,
  done_set_id TEXT NULL,
  skipped INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
''';

/// Version 3 : `sync_status` sur les items de plan (reprise multi-appareil).
const String _planItemsV3 = '''
CREATE TABLE local_session_plan_items (
  id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  exercise_position INTEGER NOT NULL,
  exercise_id TEXT NULL,
  exercise_name TEXT NOT NULL,
  set_position INTEGER NOT NULL,
  kind TEXT NOT NULL DEFAULT 'NORMAL',
  target_reps INTEGER NULL,
  target_weight_kg REAL NULL,
  rest_seconds INTEGER NULL,
  done_set_id TEXT NULL,
  skipped INTEGER NOT NULL DEFAULT 0,
  sync_status TEXT NOT NULL DEFAULT 'pending',
  PRIMARY KEY (id)
);
''';

/// Version 4 : hydratation du jour.
const String _waterIntakesV4 = '''
CREATE TABLE local_water_intakes (
  day INTEGER NOT NULL,
  milliliters INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (day)
);
''';

// ── Schémas complets ────────────────────────────────────────────────────────

/// Version 1 (Étape 4) : séances, séries, file de synchronisation.
const LegacySchema legacySchemaV1 = LegacySchema(1, [
  _sessionsV1,
  _setsV1,
  _syncOperationsV1,
]);

/// Version 2 : modèles de séance, provenance et cibles — le plan n'est pas
/// encore synchronisable.
const LegacySchema legacySchemaV2 = LegacySchema(2, [
  _sessionsV2,
  _setsV2,
  _syncOperationsV1,
  _templatesV2,
  _templateExercisesV2,
  _templateSetsV2,
  _planItemsV2,
]);

/// Version 3 : plan synchronisable (`sync_status` sur ses items).
const LegacySchema legacySchemaV3 = LegacySchema(3, [
  _sessionsV2,
  _setsV2,
  _syncOperationsV1,
  _templatesV2,
  _templateExercisesV2,
  _templateSetsV2,
  _planItemsV3,
]);

/// Version 4 : modèles, plan synchronisable et hydratation — la dernière
/// version SANS index.
const LegacySchema legacySchemaV4 = LegacySchema(4, [
  _sessionsV2,
  _setsV2,
  _syncOperationsV1,
  _templatesV2,
  _templateExercisesV2,
  _templateSetsV2,
  _planItemsV3,
  _waterIntakesV4,
]);
