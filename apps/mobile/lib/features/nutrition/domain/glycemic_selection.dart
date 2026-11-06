import '../../../core/utilities/text_search.dart';
import 'entities/glycemic_food.dart';

/// L'ordre de la liste : par famille (l'ordre de la table), ou par IG.
enum GlycemicSort { byCategory, ascending, descending }

/// Les aliments à montrer : ceux dont le nom contient [query] (sans casse ni
/// accents), de la famille [category] si elle est donnée, dans l'ordre
/// [sort]. À égalité, l'ordre de la table reste : `List.sort` n'est pas
/// stable, d'où le rang d'origine en dernier critère.
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
  kept.sort((a, b) {
    final first = switch (sort) {
      GlycemicSort.byCategory => a.$2.category.index.compareTo(
        b.$2.category.index,
      ),
      GlycemicSort.ascending => a.$2.gi.compareTo(b.$2.gi),
      GlycemicSort.descending => b.$2.gi.compareTo(a.$2.gi),
    };
    return first != 0 ? first : a.$1.compareTo(b.$1);
  });
  return [for (final (_, food) in kept) food];
}
