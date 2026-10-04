import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/nutrition.dart';

/// Le relais entre l'écran du scan et l'écran du repas neuf qu'il ouvre :
/// déposé juste avant la navigation, repris (et vidé) une fois le repas
/// prêt. Jamais deux à la fois : on ne scanne qu'une assiette à la fois.
final pendingMealScanProvider = StateProvider<MealScanSeed?>((ref) => null);
