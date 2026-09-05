/// Catalogue du MODE DÉMO, lu depuis `assets/demo/catalog.json`.
///
/// Ce fichier est ENGENDRÉ depuis le seed de l'API
/// (`pnpm --filter @carlys/api demo:catalog`) : la démo montre donc exactement
/// le même catalogue que l'application reliée au serveur. Auparavant la liste
/// était recopiée à la main dans le code, et elle avait dérivé — onze
/// exercices affichés contre cinquante-cinq au catalogue.
///
/// Les vignettes voyagent elles aussi dans l'application, faute de stockage
/// objet en démo : elles portent le schéma `asset:` que le cache d'images sait
/// résoudre, ce qui laisse aux écrans un seul chemin de code.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../core/media/remote_image_cache.dart';
import '../features/exercises/domain/entities/exercise.dart';

class DemoCatalog {
  const DemoCatalog({
    required this.exercises,
    required this.muscleGroups,
    required this.equipment,
  });

  final List<ExerciseDetail> exercises;
  final List<MuscleGroupRef> muscleGroups;
  final List<EquipmentRef> equipment;
}

DemoCatalog? _catalog;
Future<DemoCatalog>? _loading;

/// Chargé une seule fois, puis partagé — la lecture d'un asset est un vrai
/// travail asynchrone qu'on ne refait pas à chaque défilement.
///
/// C'est le RÉSULTAT qui est gardé, pas la future : une future ne s'achève que
/// dans la zone où elle est née. Garder la future faisait tenir indéfiniment
/// le second test de widget d'un même fichier, qui attendait une future créée
/// — et résolue — dans la zone de temps simulé du test précédent, désormais
/// éteinte. La future reste mémorisée le temps du chargement, uniquement pour
/// que deux appels simultanés ne lisent pas l'asset deux fois.
Future<DemoCatalog> loadDemoCatalog() async {
  final cached = _catalog;
  if (cached != null) return cached;
  final catalog = await (_loading ??= _read());
  _catalog = catalog;
  _loading = null;
  return catalog;
}

Future<DemoCatalog> _read() async {
  // `load` + `utf8.decode`, et non `loadString` : au-delà de 50 Kio ce dernier
  // délègue le décodage à un ISOLAT, qui ne s'achève jamais sous l'horloge
  // simulée d'un test de widget. Le catalogue a franchi ce seuil en passant à
  // 89 exercices, et la bibliothèque est restée bloquée sur son indicateur de
  // chargement. On n'a de toute façon aucun besoin d'un isolat : le fichier
  // est lu une seule fois, au premier affichage.
  final data = await rootBundle.load('assets/demo/catalog.json');
  final raw = utf8.decode(Uint8List.sublistView(data));
  final json = jsonDecode(raw) as Map<String, dynamic>;

  MuscleGroupRef groupOf(Map<String, dynamic> entry) => MuscleGroupRef(
    id: 'mg-${entry['slug']}',
    slug: entry['slug'] as String,
    name: entry['name'] as String,
  );
  EquipmentRef equipmentOf(Map<String, dynamic> entry) => EquipmentRef(
    id: 'eq-${entry['slug']}',
    slug: entry['slug'] as String,
    name: entry['name'] as String,
  );

  final groups = <String, MuscleGroupRef>{
    for (final entry
        in (json['muscleGroups'] as List<dynamic>)
            .whereType<Map<String, dynamic>>())
      entry['slug'] as String: groupOf(entry),
  };
  final equipment = <String, EquipmentRef>{
    for (final entry
        in (json['equipment'] as List<dynamic>)
            .whereType<Map<String, dynamic>>())
      entry['slug'] as String: equipmentOf(entry),
  };

  final exercises = <ExerciseDetail>[];
  for (final entry
      in (json['exercises'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()) {
    final slug = entry['slug'] as String;
    final primary = groups[entry['primary'] as String];
    final secondary = (entry['secondary'] as List<dynamic>)
        .whereType<String>()
        .map((s) => groups[s])
        .nonNulls
        .toList();
    exercises.add(
      ExerciseDetail(
        id: slug,
        slug: slug,
        name: entry['name'] as String,
        difficulty: ExerciseDifficulty.fromApi(entry['difficulty'] as String),
        kind: ExerciseKind.fromApi(entry['type'] as String),
        isPremium: entry['isPremium'] as bool? ?? false,
        primaryMuscleGroup: primary,
        equipment: (entry['equipment'] as List<dynamic>)
            .whereType<String>()
            .map((s) => equipment[s])
            .nonNulls
            .toList(),
        imageUrl: (entry['hasPhoto'] as bool? ?? false)
            ? '${assetImageScheme}assets/demo/exercises/$slug.webp'
            : null,
        description: entry['description'] as String,
        instructions: (entry['instructions'] as List<dynamic>)
            .whereType<String>()
            .toList(),
        tags: (entry['tags'] as List<dynamic>).whereType<String>().toList(),
        muscles: [
          if (primary != null)
            ExerciseMuscleLink(muscleGroup: primary, isPrimary: true),
          for (final group in secondary)
            ExerciseMuscleLink(muscleGroup: group, isPrimary: false),
        ],
      ),
    );
  }

  // Les groupes SANS exercice ne sont pas montrés : une case vide dans la
  // grille des muscles n'apprend rien et donne l'impression d'un bug.
  final used = exercises
      .map((e) => e.primaryMuscleGroup?.slug)
      .nonNulls
      .toSet();
  return DemoCatalog(
    exercises: exercises,
    muscleGroups: groups.values
        .where((group) => used.contains(group.slug))
        .toList(),
    equipment: equipment.values.toList(),
  );
}
