import '../../../core/utilities/text_search.dart';
import 'entities/glycemic_food.dart';

/// L'ordre de la liste : par famille (celui du pack), ou par IG.
enum GlycemicSort { byCategory, ascending, descending }

/// Les aliments à montrer : ceux dont le nom contient [query] (sans casse ni
/// accents), de la famille [category] si elle est donnée, dans l'ordre
/// [sort]. Par famille, rien ne se trie : le pack est déjà rangé famille
/// par famille (sa garde le vérifie). Par IG, à égalité, l'ordre du pack
/// reste : `List.sort` n'est pas stable, d'où le rang en dernier critère.
List<GlycemicFood> glycemicFoodsFor(
  List<GlycemicFood> foods, {
  String query = '',
  GlycemicCategory? category,
  GlycemicSort sort = GlycemicSort.byCategory,
}) {
  final kept = [
    for (final (rank, food) in foods.indexed)
      if ((category == null || food.category == category) &&
          matchesSearch(food.name, query))
        (rank, food),
  ];
  final direction = switch (sort) {
    GlycemicSort.byCategory => 0,
    GlycemicSort.ascending => 1,
    GlycemicSort.descending => -1,
  };
  if (direction != 0) {
    kept.sort((a, b) {
      final first = direction * a.$2.gi.compareTo(b.$2.gi);
      return first != 0 ? first : a.$1.compareTo(b.$1);
    });
  }
  return [for (final (_, food) in kept) food];
}
