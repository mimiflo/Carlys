import 'dart:async';

import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_sync_api.dart';
import '../support/fake_workout_repository.dart';
import '../support/in_memory_workout_template_repository.dart';

/// Le rapatriement d'un téléphone neuf : pousser d'abord, puis tirer les
/// modèles ET les séances — ENSEMBLE. Les deux lectures ne dépendent pas
/// l'une de l'autre (aucune clé étrangère locale) : en file, l'historique
/// attendait que le dernier modèle soit arrivé.
void main() {
  late AppDatabase db;
  late _Seances seances;
  late _Modeles modeles;
  late AppRestore restore;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    seances = _Seances();
    modeles = _Modeles(seances);
    restore = AppRestore(
      syncEngine: SyncEngine(database: db, api: FakeSyncApi()),
      workouts: seances,
      templates: modeles,
    );
  });

  tearDown(() => db.close());

  test('modèles et séances se rapatrient en même temps', () async {
    restore.ensureRestored();
    await pumpEventQueue();

    // Les modèles ne sont pas revenus, les séances sont déjà en route.
    expect(modeles.enCours, isTrue);
    expect(seances.demandes, 1);

    modeles.fin.complete();
    seances.fin.complete();
    await restore.cancelAndWait();
  });

  test('annuler attend la fin des DEUX lectures', () async {
    restore.ensureRestored();
    await pumpEventQueue();

    var rendu = false;
    unawaited(restore.cancelAndWait().then((_) => rendu = true));
    modeles.fin.complete();
    await pumpEventQueue();
    // Une lecture encore en vol pourrait écrire dans la base purgée.
    expect(rendu, isFalse);

    seances.fin.complete();
    await pumpEventQueue();
    expect(rendu, isTrue);
    expect(seances.arretDemande, isTrue);
    // Les modèles reçoivent le MÊME arrêt que les séances.
    expect(modeles.continuer!(), isFalse);
  });
}

class _Seances extends FakeWorkoutRepository {
  final fin = Completer<void>();
  int demandes = 0;
  bool arretDemande = false;

  @override
  Future<void> restoreSessions({bool Function()? shouldContinue}) async {
    demandes++;
    await fin.future;
    arretDemande = !(shouldContinue?.call() ?? true);
  }
}

class _Modeles extends InMemoryWorkoutTemplateRepository {
  _Modeles(super.workouts);

  final fin = Completer<void>();
  bool enCours = false;
  bool Function()? continuer;

  @override
  Future<void> refreshTemplates({bool Function()? shouldContinue}) async {
    continuer = shouldContinue;
    enCours = true;
    await fin.future;
    enCours = false;
  }
}
