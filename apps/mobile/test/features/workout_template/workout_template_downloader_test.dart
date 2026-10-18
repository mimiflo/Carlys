import 'dart:async';
import 'dart:math';

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/data/datasources/workout_template_local_data_source.dart';
import 'package:carlys_mobile/features/workout_template/data/datasources/workout_template_remote_data_source.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_downloader.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// LE RAPATRIEMENT DES MODÈLES ne réécrit que ce qui a changé.
///
/// Chaque lancement à froid retéléchargeait (`GET /workout-templates/:id`)
/// et réécrivait chaque modèle, identique ou non : la liste portait pourtant
/// déjà sa date de modification.
void main() {
  late AppDatabase db;
  late _Serveur serveur;
  late WorkoutTemplateDownloader downloader;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    serveur = _Serveur();
    downloader = WorkoutTemplateDownloader(
      database: db,
      local: WorkoutTemplateLocalDataSource(db),
      remote: serveur,
    );
  });

  tearDown(() => db.close());

  test('une base déjà à jour : aucun détail relu, rien réécrit', () async {
    await downloader.run();
    expect(serveur.details, ['push', 'jambes']);

    serveur.details.clear();
    await downloader.run();

    expect(serveur.details, isEmpty);
  });

  test('un modèle modifié ailleurs est relu, lui seul', () async {
    await downloader.run();
    serveur.details.clear();

    serveur.modifier('jambes', DateTime.utc(2026, 9, 20, 18, 30, 12, 345));
    await downloader.run();

    expect(serveur.details, ['jambes']);
  });

  test('un modèle LANCÉ ailleurs (dernière utilisation) est relu', () async {
    await downloader.run();
    serveur.details.clear();

    serveur.lancer('push', DateTime.utc(2026, 9, 24, 7, 5));
    await downloader.run();

    expect(serveur.details, ['push']);
  });

  test(
    'un modèle rangé AVANT la catégorie Coach est relu pour la recevoir',
    () async {
      await downloader.run();
      serveur.details.clear();

      serveur.duCoach('jambes');
      await downloader.run();

      expect(serveur.details, ['jambes']);
      final rows = await db.select(db.localWorkoutTemplates).get();
      expect(
        {for (final r in rows) r.id: r.fromCoach},
        {'push': false, 'jambes': true},
      );
    },
  );

  test('les détails se demandent par lots, pas un à un', () async {
    // Sur un téléphone neuf, chaque modèle attendait la réponse du
    // précédent : quinze modèles, quinze allers-retours en file.
    serveur.remplir();
    await downloader.run();

    expect(serveur.details, hasLength(15));
    expect(serveur.maxInFlight, inInclusiveRange(2, 6));
    // Tous écrits.
    expect(await db.select(db.localWorkoutTemplates).get(), hasLength(15));
  });

  test('une purge en vol arrête le rapatriement avant tout détail', () async {
    await downloader.run(shouldContinue: () => false);

    expect(serveur.details, isEmpty);
    expect(await db.select(db.localWorkoutTemplates).get(), isEmpty);
  });

  group('une saisie locale PENDANT le téléchargement gagne', () {
    late WorkoutTemplateRepositoryImpl templates;

    setUp(() async {
      templates = WorkoutTemplateRepositoryImpl(
        database: db,
        // Réseau coupé pour la file : la saisie reste `pending`, ce qui est
        // exactement l'état que le rapatriement doit respecter.
        syncEngine: SyncEngine(
          database: db,
          api: FakeSyncApi()..networkDown = true,
        ),
      );
      await downloader.run();
      // Modifié ailleurs : le prochain rapatriement le relit.
      serveur.modifier('push', DateTime.utc(2026, 9, 20, 18, 30));
      serveur.gate = Completer<void>();
    });

    test('un modèle supprimé ici ne ressuscite pas', () async {
      final run = downloader.run();
      await pumpEventQueue();
      expect(serveur.details, contains('push'), reason: 'détail en vol');

      await templates.deleteTemplate('push');
      serveur.gate!.complete();
      await run;

      final push = await (db.select(
        db.localWorkoutTemplates,
      )..where((row) => row.id.equals('push'))).getSingle();
      expect(push.deleted, isTrue);
      expect(push.syncStatus, 'pending');
    });

    test('un modèle retouché ici garde sa retouche', () async {
      final run = downloader.run();
      await pumpEventQueue();

      await templates.saveTemplate(
        const SaveTemplateInput(
          id: 'push',
          name: 'Push retouché',
          exercises: [
            TemplateExerciseInput(
              exerciseName: 'Développé couché',
              sets: [PlannedSetInput(targetReps: 8)],
            ),
          ],
        ),
      );
      serveur.gate!.complete();
      await run;

      final push = await (db.select(
        db.localWorkoutTemplates,
      )..where((row) => row.id.equals('push'))).getSingle();
      expect(push.name, 'Push retouché');
      expect(push.syncStatus, 'pending');
    });
  });
}

class _Serveur implements WorkoutTemplateRemoteDataSource {
  final Map<String, WorkoutTemplateInfo> _modeles = {
    for (final (id, nom) in [('push', 'Push'), ('jambes', 'Jambes')])
      id: WorkoutTemplateInfo(
        id: id,
        name: nom,
        exercisesCount: 0,
        plannedSetsCount: 0,
        previewExerciseNames: const [],
        // Des millisecondes, en UTC, comme les sert l'API.
        updatedAt: DateTime.utc(2026, 9, 1, 10, 0, 0, 123),
        syncState: LocalSyncState.synced,
      ),
  };

  final List<String> details = [];

  /// Retient la réponse des détails tant qu'un test ne l'ouvre pas : de quoi
  /// placer une saisie locale PENDANT le téléchargement.
  Completer<void>? gate;

  /// Détails en vol en même temps, au plus fort.
  int inFlight = 0;
  int maxInFlight = 0;

  /// Treize modèles de plus, tous inconnus de l'appareil.
  void remplir() {
    for (var i = 0; i < 13; i++) {
      final modele = _modeles['push']!;
      _modeles['m$i'] = WorkoutTemplateInfo(
        id: 'm$i',
        name: 'Modèle $i',
        exercisesCount: 0,
        plannedSetsCount: 0,
        previewExerciseNames: const [],
        updatedAt: modele.updatedAt,
        syncState: LocalSyncState.synced,
      );
    }
  }

  void modifier(String id, DateTime quand) =>
      _modeles[id] = _copie(_modeles[id]!, updatedAt: quand);

  void lancer(String id, DateTime quand) =>
      _modeles[id] = _copie(_modeles[id]!, lastUsedAt: quand);

  void duCoach(String id) => _modeles[id] = _copie(_modeles[id]!, coach: true);

  static WorkoutTemplateInfo _copie(
    WorkoutTemplateInfo info, {
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    bool? coach,
  }) => WorkoutTemplateInfo(
    id: info.id,
    name: info.name,
    exercisesCount: info.exercisesCount,
    plannedSetsCount: info.plannedSetsCount,
    previewExerciseNames: info.previewExerciseNames,
    updatedAt: updatedAt ?? info.updatedAt,
    lastUsedAt: lastUsedAt ?? info.lastUsedAt,
    fromCoach: coach ?? info.fromCoach,
    syncState: info.syncState,
  );

  @override
  Future<WorkoutTemplatesPage> list({String? cursor, int? limit}) async =>
      WorkoutTemplatesPage(items: _modeles.values.toList(), hasMore: false);

  @override
  Future<WorkoutTemplateDetail> detail(String templateId) async {
    details.add(templateId);
    maxInFlight = max(maxInFlight, ++inFlight);
    // Un aller-retour réseau : rend la main avant de répondre.
    await Future<void>.delayed(Duration.zero);
    await gate?.future;
    inFlight--;
    return WorkoutTemplateDetail(info: _modeles[templateId]!, exercises: []);
  }
}
