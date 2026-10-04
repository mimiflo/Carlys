import 'dart:typed_data';

import 'food.dart';

/// Où en est le scan d'une assiette.
enum MealScanStatus {
  pending,
  done,
  failed;

  static MealScanStatus fromApi(Object? value) => switch (value) {
    'DONE' => MealScanStatus.done,
    'FAILED' => MealScanStatus.failed,
    _ => MealScanStatus.pending,
  };
}

/// Un aliment vu sur la photo : son nom selon le modèle, sa masse estimée,
/// et l'aliment de la base CIQUAL qui lui correspond (`null` : aucun).
class MealScanItem {
  const MealScanItem({required this.seen, required this.grams, this.food});

  final String seen;
  final int grams;
  final Food? food;
}

/// Le scan d'une assiette par le modèle de vision : le modèle reconnaît,
/// la base CIQUAL donne les valeurs — aucun chiffre nutritionnel inventé.
class MealScan {
  const MealScan({
    required this.id,
    required this.status,
    this.items = const [],
    this.error,
  });

  final String id;
  final MealScanStatus status;
  final List<MealScanItem> items;

  /// Pourquoi il a échoué, écrit pour la personne par le serveur.
  final String? error;
}

/// Le scan, et la mention de la base CIQUAL (version comprise).
typedef MealScanResult = ({MealScan scan, FoodSource source});

/// Ce qu'un scan d'assiette laisse à l'écran de repas qui s'ouvre après lui :
/// la photo prise, les aliments reconnus et la mention de la base.
typedef MealScanSeed = ({
  Uint8List photo,
  List<MealScanItem> items,
  FoodSource source,
});
