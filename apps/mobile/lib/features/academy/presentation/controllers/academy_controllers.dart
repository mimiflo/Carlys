import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/academy_pack.dart';
import '../../domain/entities/academy.dart';

/// Le pack d'apprentissage, chargé une fois par processus.
final academyPackProvider = FutureProvider<List<Lesson>>((ref) {
  return loadAcademyPack();
});

/// La leçon du jour — déterministe : le jour de l'année parcourt le pack en
/// boucle. Tout le monde a la même question le même jour, et elle change
/// chaque matin sans aucun tirage aléatoire.
final dailyLessonProvider = Provider<Lesson?>((ref) {
  final lessons = ref.watch(academyPackProvider).valueOrNull;
  if (lessons == null || lessons.isEmpty) {
    return null;
  }
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  return lessons[dayOfYear % lessons.length];
});
