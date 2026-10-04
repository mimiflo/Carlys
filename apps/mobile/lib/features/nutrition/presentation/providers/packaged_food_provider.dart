import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/nutrition_repository_impl.dart';
import '../../domain/entities/nutrition.dart';

/// Le produit d'un code-barres scanné : `null` s'il est inconnu de la base.
/// `autoDispose` : il vit le temps de la feuille qui le montre.
final packagedFoodProvider = FutureProvider.autoDispose
    .family<PackagedFoodResult?, String>(
      (ref, barcode) =>
          ref.watch(nutritionRepositoryProvider).productByBarcode(barcode),
    );
