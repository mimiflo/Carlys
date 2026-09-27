/// Les données LOCALES d'un harnais qui monte `CarlysApp`, en mémoire.
///
/// Sans elles, l'accueil lisait `workoutTemplatesProvider`, qui montait le
/// VRAI `appDatabaseProvider` (une base Drift sur le dossier de documents de
/// l'appareil, qu'un banc de test ne peut pas ouvrir) et le vrai moteur de
/// synchronisation. Drift imprimait à chaque montage « created the database
/// class AppDatabase multiple times » suivi d'une pile d'environ 600 lignes :
/// 117 blocs sur la suite, 96 % du journal des tests mobiles. Un échec réel
/// s'y noyait (celui de Los Angeles était à la ligne 34 636 sur 71 000). Et
/// la section « modèles » de l'accueil ne lisait jamais une donnée de test.
///
/// `progress_flow_test` décrivait déjà le piège et le contournait à la main ;
/// c'est ce contournement, rangé ici pour tous.
library;

import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_workout_repository.dart';
import 'in_memory_workout_template_repository.dart';

/// Séances ET modèles en mémoire, les seconds branchés sur les premières
/// (lancer un modèle démarre une séance du même dépôt).
List<Override> localDataOverrides([FakeWorkoutRepository? workouts]) {
  final seances = workouts ?? FakeWorkoutRepository();
  return [
    workoutRepositoryProvider.overrideWithValue(seances),
    workoutTemplateRepositoryProvider.overrideWithValue(
      InMemoryWorkoutTemplateRepository(seances),
    ),
  ];
}
