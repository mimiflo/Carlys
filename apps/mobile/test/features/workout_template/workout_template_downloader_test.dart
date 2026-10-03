import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/data/datasources/workout_template_local_data_source.dart';
import 'package:carlys_mobile/features/workout_template/data/datasources/workout_template_remote_data_source.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_downloader.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
    return WorkoutTemplateDetail(info: _modeles[templateId]!, exercises: []);
  }
}
