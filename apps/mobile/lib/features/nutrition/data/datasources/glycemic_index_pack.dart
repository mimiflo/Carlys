/// Chargement du tableau des index glycémiques embarqué
/// (`assets/nutrition/glycemic_index.json`).
///
/// Même patron que le pack de recettes : un contenu éditorial qui doit
/// s'ouvrir hors ligne, sans aucune route d'API.
library;

import '../../../../core/utilities/embedded_pack.dart';
import '../../domain/entities/glycemic_food.dart';

final _pack = EmbeddedPack<GlycemicFood>(
  asset: 'assets/nutrition/glycemic_index.json',
  listKey: 'foods',
  parse: _food,
  emptyMessage: 'tableau des index glycémiques vide',
);

Future<List<GlycemicFood>> loadGlycemicIndexPack() => _pack.load();

/// Réservé aux tests, qui vérifient le rechargement.
void resetGlycemicIndexPackCache() => _pack.reset();

GlycemicFood _food(Map<String, dynamic> json) {
  final mark = json['mark'] as String?;
  return GlycemicFood(
    name: json['name'] as String,
    category: GlycemicCategory.values.byName(json['category'] as String),
    gi: json['gi'] as int,
    sem: json['sem'] as int,
    mark: mark == null ? null : GlycemicMark.values.byName(mark),
  );
}
