/// Une base MISE À JOUR doit avoir exactement la forme d'une base NEUVE.
///
/// Pourquoi ce test existe. Ajouter une colonne à une table Drift sans
/// incrémenter `schemaVersion` traverse `dart run build_runner build`,
/// `flutter analyze` (« No issues found! ») et la totalité de la suite de
/// tests : tous ces outils lisent le code Dart, jamais la base réellement
/// obtenue. Le résultat n'apparaît que chez l'utilisateur qui MET À JOUR
/// l'application — sa base n'est pas recréée, `onUpgrade` n'est pas appelé,
/// et la première écriture rend `SqliteException(1): table
/// local_workout_sessions has no column named coach_notes`. L'installation
/// neuve, elle, est impeccable : c'est précisément ce qui rend l'oubli
/// invisible en développement.
///
/// Ce que ce filet compare : la forme déclarée par SQLite lui-même
/// (`sqlite_master`, `pragma_table_info`) d'une base montée depuis chaque
/// palier historique connu, face à celle qu'`onCreate` produit. Il attrape
/// donc l'oubli d'incrément de `schemaVersion` ET l'étape de migration
/// manquante ou incomplète.
///
/// Ce qu'il n'attrape PAS, et il faut le savoir : une migration
/// DESTRUCTIVE. Si une étape recrée une table en perdant ses lignes, la base
/// migrée et la base neuve ont la même forme et concordent — les deux
/// passent. Attraper ce cas-là demande autre chose : partir d'un palier
/// historique PEUPLÉ et vérifier que les lignes, leurs valeurs et leurs
/// clés survivent au passage, ce que fait `app_database_migration_test.dart`
/// palier par palier. Le filet complet serait de générer ces données de
/// départ pour CHAQUE palier au lieu de les écrire à la main, et de
/// comparer aussi le contenu — non construit ici.
///
/// Les contraintes `CHECK` posées par Drift sur les booléens sortent aussi
/// du filet : `pragma_table_info` ne les expose pas.
library;

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/database_shape.dart';
import '../support/legacy_schemas.dart';

void main() {
  /// La forme qu'obtient une installation NEUVE : `onCreate` → `createAll`,
  /// c'est-à-dire la traduction directe des tables déclarées aujourd'hui.
  ///
  /// Lue UNE fois, avant toute base historique : deux `AppDatabase` vivantes
  /// en même temps déclenchent l'avertissement de Drift sur les instances
  /// multiples, qui noierait le message d'un vrai échec.
  late DatabaseShape fresh;
  late int schemaVersion;

  setUpAll(() async {
    final db = AppDatabase(NativeDatabase.memory());
    schemaVersion = db.schemaVersion;
    fresh = await readDatabaseShape(db);
    await db.close();
  });

  test('la version déclarée dépasse tous les paliers historiques rejoués', () {
    // Formulée en « strictement supérieur au plus haut palier figé » et non
    // « égale à 5 » : une assertion sur une constante écrite en dur est
    // muette sur l'oubli d'incrément (le seul défaut qui compte) et proteste
    // quand quelqu'un incrémente CORRECTEMENT.
    expect(
      schemaVersion,
      greaterThan(highestLegacyVersion),
      reason:
          'schemaVersion ($schemaVersion) doit dépasser le plus haut palier '
          'historique rejoué par legacy_schemas.dart '
          '($highestLegacyVersion) : un palier figé là-bas est une version '
          'révolue.',
    );
  });

  for (final schema in legacySchemas) {
    test('une base montée depuis la version ${schema.version} a la forme '
        "d'une base neuve", () async {
      final db = openLegacyDatabase(schema);
      addTearDown(db.close);

      // La première requête déclenche `onUpgrade` : c'est le chemin exact
      // d'un utilisateur qui met à jour l'application.
      final migrated = await readDatabaseShape(db);

      final differences = shapeDifferences(migrated, fresh);
      expect(
        differences,
        isEmpty,
        reason:
            'Une base montée de la version ${schema.version} vers '
            '${db.schemaVersion} ne ressemble pas à une base neuve. '
            'Les utilisateurs qui METTENT À JOUR auront cette base-là, et '
            'la première écriture sur un objet manquant lèvera une '
            'SqliteException. Deux causes possibles : une table a changé '
            'sans que `schemaVersion` soit incrémenté, ou la branche '
            "correspondante d'`onUpgrade` est absente ou incomplète.\n"
            '  - ${differences.join('\n  - ')}',
      );
    });
  }
}
