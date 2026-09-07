/// Lecture de la FORME d'une base SQLite ouverte : tables, colonnes, index.
///
/// « Forme » au sens de ce que SQLite lui-même déclare — `sqlite_master` et
/// `pragma_table_info` — et non de ce que Drift croit avoir écrit. C'est la
/// distinction qui donne sa valeur au test de forme : une base neuve et une
/// base migrée passent toutes deux par le même code Dart, mais seule la
/// première a exécuté `createAll`.
library;

import 'package:carlys_mobile/core/database/app_database.dart';

/// Forme complète d'une base, dans une structure comparable et affichable.
class DatabaseShape {
  const DatabaseShape({required this.columnsByTable, required this.indexes});

  /// Nom de table → (nom de colonne → signature lisible).
  ///
  /// Les colonnes sont indexées PAR NOM et jamais par position : une colonne
  /// ajoutée par `ALTER TABLE` arrive en fin de table alors que `createAll`
  /// la place dans l'ordre de déclaration. L'ordre diverge donc légitimement
  /// et ne dit rien de la justesse de la migration.
  final Map<String, Map<String, String>> columnsByTable;

  /// Nom d'index → sa définition SQL normalisée (`null` pour les index que
  /// SQLite crée lui-même derrière une clé primaire).
  final Map<String, String?> indexes;
}

/// Signature lisible d'une colonne, telle que `pragma_table_info` la décrit.
///
/// Volontairement limitée à ce que ce pragma expose : type, nullabilité,
/// valeur par défaut, appartenance à la clé primaire. Les contraintes
/// `CHECK` (Drift en pose une sur les booléens) n'y figurent pas et sortent
/// donc du filet.
String _columnSignature(
  String type,
  int notNull,
  String? defaultValue,
  int primaryKey,
) {
  return [
    type.isEmpty ? 'SANS TYPE' : type,
    notNull != 0 ? 'NOT NULL' : 'NULL',
    if (defaultValue != null) 'DEFAULT $defaultValue',
    if (primaryKey > 0) 'PK($primaryKey)',
  ].join(' ');
}

/// Espaces et retours à la ligne réduits à une espace simple : deux DDL
/// identiques au formatage près doivent se comparer égales.
String _normalize(String sql) => sql.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Lit la forme de [db]. La première requête déclenche `onCreate` ou
/// `onUpgrade` selon l'état de la base, ce qui est exactement le but.
Future<DatabaseShape> readDatabaseShape(AppDatabase db) async {
  final tableRows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();

  final columnsByTable = <String, Map<String, String>>{};
  for (final tableRow in tableRows) {
    final table = tableRow.read<String>('name');
    // Le nom vient de `sqlite_master`, pas d'une entrée utilisateur : il est
    // sûr à interpoler, et `pragma_table_info` n'accepte pas toujours un
    // paramètre lié selon la version de SQLite.
    final columnRows = await db
        .customSelect("SELECT * FROM pragma_table_info('$table')")
        .get();
    columnsByTable[table] = {
      for (final column in columnRows)
        column.read<String>('name'): _columnSignature(
          column.read<String>('type'),
          column.read<int>('notnull'),
          column.read<String?>('dflt_value'),
          column.read<int>('pk'),
        ),
    };
  }

  final indexRows = await db
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'index' "
        'ORDER BY name',
      )
      .get();

  final indexes = <String, String?>{};
  for (final index in indexRows) {
    final sql = index.read<String?>('sql');
    indexes[index.read<String>('name')] = sql == null ? null : _normalize(sql);
  }

  return DatabaseShape(columnsByTable: columnsByTable, indexes: indexes);
}

/// Les écarts entre deux formes, un par ligne, prêts à être affichés.
///
/// [migrated] est la base montée depuis un schéma historique, [fresh] celle
/// qu'une installation neuve obtient. Chaque écart NOMME l'objet fautif :
/// c'est le seul moyen qu'un échec se lise sans ouvrir un débogueur.
List<String> shapeDifferences(DatabaseShape migrated, DatabaseShape fresh) {
  final differences = <String>[];

  for (final table in fresh.columnsByTable.keys) {
    final freshColumns = fresh.columnsByTable[table]!;
    final migratedColumns = migrated.columnsByTable[table];
    if (migratedColumns == null) {
      differences.add(
        'table manquante après migration : $table '
        '(${freshColumns.length} colonnes dans une base neuve)',
      );
      continue;
    }
    for (final entry in freshColumns.entries) {
      final migratedSignature = migratedColumns[entry.key];
      if (migratedSignature == null) {
        differences.add(
          'colonne manquante après migration : $table.${entry.key} '
          '(${entry.value} dans une base neuve)',
        );
      } else if (migratedSignature != entry.value) {
        differences.add(
          'colonne divergente : $table.${entry.key} — '
          'base migrée « $migratedSignature », base neuve « ${entry.value} »',
        );
      }
    }
    for (final column in migratedColumns.keys) {
      if (!freshColumns.containsKey(column)) {
        differences.add(
          'colonne en trop après migration : $table.$column '
          '(absente d’une base neuve)',
        );
      }
    }
  }

  for (final table in migrated.columnsByTable.keys) {
    if (!fresh.columnsByTable.containsKey(table)) {
      differences.add(
        'table en trop après migration : $table '
        '(absente d’une base neuve)',
      );
    }
  }

  for (final entry in fresh.indexes.entries) {
    if (!migrated.indexes.containsKey(entry.key)) {
      differences.add('index manquant après migration : ${entry.key}');
    } else if (migrated.indexes[entry.key] != entry.value) {
      differences.add(
        'index divergent : ${entry.key} — '
        'base migrée « ${migrated.indexes[entry.key]} », '
        'base neuve « ${entry.value} »',
      );
    }
  }
  for (final index in migrated.indexes.keys) {
    if (!fresh.indexes.containsKey(index)) {
      differences.add('index en trop après migration : $index');
    }
  }

  return differences;
}
