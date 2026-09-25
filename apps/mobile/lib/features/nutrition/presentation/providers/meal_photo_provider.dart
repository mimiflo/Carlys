import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/meal_photo_cache.dart';

/// Quelle photo : celle du repas [mealId], dans sa version [updatedAt].
typedef MealPhotoKey = ({String mealId, DateTime updatedAt});

/// Les octets de la photo d'un repas, lus par le GET authentifié du dépôt
/// et gardés par [MealPhotoCache] sous (repas, date de la photo).
///
/// `null` : le serveur n'a pas (ou plus) de photo. En erreur : le réseau a
/// manqué — l'écran montre alors la vignette dessinée, jamais un trou.
/// `autoDispose` : la référence aux octets tombe avec la vignette ; la
/// conservation est le travail du cache, borné en mémoire.
final mealPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List?, MealPhotoKey>(
      (ref, key) =>
          ref.watch(mealPhotoCacheProvider).read(key.mealId, key.updatedAt),
    );
