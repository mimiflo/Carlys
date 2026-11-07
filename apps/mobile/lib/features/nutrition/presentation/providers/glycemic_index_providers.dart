import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/glycemic_index_pack.dart';
import '../../domain/entities/glycemic_food.dart';

/// Le tableau embarqué. Sans `autoDispose`, comme le pack de recettes : le
/// contenu ne change jamais en cours de session.
final glycemicIndexPackProvider = FutureProvider<List<GlycemicFood>>((ref) {
  return loadGlycemicIndexPack();
});
