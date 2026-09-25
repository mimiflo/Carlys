import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/nutrition_repository.dart';
import 'nutrition_repository_impl.dart';

/// Les photos de repas déjà lues, gardées EN MÉMOIRE, par (repas, date de
/// la photo).
///
/// **La clé porte `photo.updatedAt`.** L'adresse d'une photo
/// (`…/meals/:id/photo`) ne change pas quand on la remplace : seule sa date
/// le dit. Une clé par date rend l'invalidation triviale — une photo
/// remplacée a une autre clé, l'ancienne n'est simplement plus demandée.
///
/// **En mémoire seulement, jamais sur le disque.** Le cache des images du
/// catalogue (`DiskRemoteImageCache`) écrit sur le disque des images
/// PUBLIQUES ; une photo de repas est privée, et n'a pas à survivre sur le
/// téléphone à la session qui l'a montrée. Le budget est borné par OCTETS,
/// les plus anciennement vues partent d'abord.
class MealPhotoCache {
  MealPhotoCache(this._repository, {this.budgetBytes = defaultBudgetBytes});

  final NutritionRepository _repository;

  /// Quelques dizaines de photos préparées (quelques centaines de Ko
  /// chacune) : de quoi repasser d'un repas à l'autre sans relire le réseau.
  static const int defaultBudgetBytes = 12 * 1024 * 1024;

  final int budgetBytes;

  /// L'ordre d'insertion d'une `Map` littérale (un `LinkedHashMap`) est
  /// l'ordre d'éviction : relire une photo la remet en queue.
  final Map<String, Uint8List> _memory = {};
  int _bytes = 0;

  /// Lectures en cours, partagées : deux écrans qui demandent la même photo
  /// n'en font qu'une requête.
  final Map<String, Future<Uint8List?>> _inFlight = {};

  @visibleForTesting
  int get bytes => _bytes;

  /// Les octets de la photo du repas [mealId] datée [updatedAt] ; `null`
  /// quand le serveur n'en a plus. Lève si le réseau ou le serveur manque :
  /// l'écran retombe alors sur la vignette dessinée.
  Future<Uint8List?> read(String mealId, DateTime updatedAt) {
    final key = _key(mealId, updatedAt);
    final cached = _memory[key];
    if (cached != null) {
      return Future.value(_remember(key, cached));
    }
    return _inFlight.putIfAbsent(key, () => _fetch(mealId, key));
  }

  /// Range les octets qu'on vient d'ENVOYER sous la date que le serveur leur
  /// a donnée : rouvrir le repas ne retélécharge pas ce qu'on a sous la
  /// main.
  void remember(String mealId, DateTime updatedAt, Uint8List jpeg) {
    forget(mealId);
    _remember(_key(mealId, updatedAt), jpeg);
  }

  /// Oublie toutes les versions de la photo d'un repas (retirée, repas
  /// supprimé).
  void forget(String mealId) {
    final prefix = '$mealId@';
    final stale = [
      for (final key in _memory.keys)
        if (key.startsWith(prefix)) key,
    ];
    for (final key in stale) {
      _bytes -= _memory.remove(key)!.lengthInBytes;
    }
  }

  Future<Uint8List?> _fetch(String mealId, String key) async {
    try {
      final bytes = await _repository.mealPhoto(mealId);
      return bytes == null ? null : _remember(key, bytes);
    } finally {
      // La future retirée EST celle qui s'achève ici : l'appelant l'attend
      // déjà, rien d'autre à en faire.
      _inFlight.remove(key)?.ignore();
    }
  }

  Uint8List _remember(String key, Uint8List bytes) {
    final previous = _memory.remove(key);
    if (previous != null) {
      _bytes -= previous.lengthInBytes;
    }
    _memory[key] = bytes;
    _bytes += bytes.lengthInBytes;
    while (_bytes > budgetBytes && _memory.length > 1) {
      final oldest = _memory.keys.first;
      _bytes -= _memory.remove(oldest)!.lengthInBytes;
    }
    return bytes;
  }

  static String _key(String mealId, DateTime updatedAt) =>
      '$mealId@${updatedAt.toUtc().toIso8601String()}';
}

/// UN cache pour toute l'application : il survit aux écrans, pas à la
/// session (il vit en mémoire).
final mealPhotoCacheProvider = Provider<MealPhotoCache>(
  (ref) => MealPhotoCache(ref.watch(nutritionRepositoryProvider)),
);
