import 'food.dart';

/// Un produit emballé, trouvé par son code-barres dans Open Food Facts —
/// interrogé par l'API, jamais par l'appareil.
class PackagedFood {
  const PackagedFood({
    required this.barcode,
    required this.name,
    required this.per100g,
    this.brand,
    this.liquid = false,
    this.servingQuantity,
  });

  final String barcode;
  final String name;
  final String? brand;

  /// Pour 100 g, ou pour 100 ml quand [liquid].
  final FoodPer100g per100g;
  final bool liquid;

  /// Une portion selon l'emballage (g ou ml), si elle est donnée.
  final double? servingQuantity;
}

/// Le produit, et la mention de la base (licence ODbL) à afficher près de
/// ses valeurs.
typedef PackagedFoodResult = ({PackagedFood food, FoodAttribution source});
