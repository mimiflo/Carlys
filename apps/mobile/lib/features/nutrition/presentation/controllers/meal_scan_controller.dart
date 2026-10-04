import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../data/repositories/nutrition_repository_impl.dart';
import '../../data/services/image_picker_meal_photo_picker.dart';
import '../../domain/entities/nutrition.dart';

/// Où en est l'écran du scan d'assiette.
enum MealScanPhase { choosing, preparing, analyzing, failed }

/// Ce que l'écran montre : l'étape, la photo prise, depuis quand le modèle
/// travaille, et pourquoi le scan a échoué.
typedef MealScanView = ({
  MealScanPhase phase,
  Uint8List? photo,
  DateTime? since,
  String? error,
});

/// Le scan d'une assiette, de la photo au repas pré-rempli.
///
/// La photo part au serveur, qui la fait lire par le modèle de vision EN
/// FOND : sur un processeur, l'analyse prend une à deux minutes. L'écran
/// relit le scan toutes les [_every] jusqu'à son résultat. Il le rend au
/// repas sous la forme d'un [MealScanSeed] ; l'écran ouvre alors le repas.
class MealScanController extends AutoDisposeNotifier<MealScanView> {
  static const _uuid = Uuid();
  static const _logger = AppLogger('MealScan');
  static const Duration _every = Duration(seconds: 2);

  /// L'échéance du serveur (file, analyse) et de la marge : au-delà, on
  /// renonce.
  static const Duration _patience = Duration(minutes: 8);

  static const MealScanView _choosing = (
    phase: MealScanPhase.choosing,
    photo: null,
    since: null,
    error: null,
  );

  bool _disposed = false;

  @override
  MealScanView build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return _choosing;
  }

  void retry() => state = _choosing;

  /// Prend (ou choisit) la photo et la fait analyser. Rend les aliments
  /// reconnus, ou `null` : renoncé, ou échoué (l'écran dit pourquoi).
  Future<MealScanSeed?> scan(MealPhotoSource source) async {
    // Un second appui pendant que la photo s'ouvre : un seul scan.
    if (state.phase != MealScanPhase.choosing) return null;
    state = (
      phase: MealScanPhase.preparing,
      photo: null,
      since: null,
      error: null,
    );
    final Uint8List? photo;
    try {
      photo = await ref.read(mealPhotoPickerProvider).pick(source);
    } on MealPhotoException {
      if (!_disposed) state = _choosing;
      rethrow;
    }
    if (photo == null || _disposed) {
      if (!_disposed) state = _choosing;
      return null;
    }
    final since = DateTime.now();
    state = (
      phase: MealScanPhase.analyzing,
      photo: photo,
      since: since,
      error: null,
    );
    try {
      final result = await _analyse(_uuid.v4(), photo, since);
      if (result == null) return null;
      final scan = result.scan;
      if (scan.status == MealScanStatus.failed) {
        return _fail(scan.error ?? _failedMessage);
      }
      if (!scan.items.any((item) => item.food != null)) {
        return _fail(
          scan.items.isEmpty
              ? 'Aucun aliment reconnu sur cette photo. Rapproche-toi de '
                    'l’assiette, en pleine lumière, ou saisis le repas à la main.'
              : 'Ce que l’IA a vu (${scan.items.map((i) => i.seen).join(', ')}) '
                    'n’est pas dans la base. Saisis le repas à la main.',
        );
      }
      return (photo: photo, items: scan.items, source: result.source);
    } on AppException catch (error) {
      return _fail(_messageFor(error));
    } on Object catch (error, stack) {
      // Jamais une attente sans fin : tout autre échec se dit aussi.
      _logger.error('Scan d’assiette', error: error, stackTrace: stack);
      return _fail(_failedMessage);
    }
  }

  Future<MealScanResult?> _analyse(
    String id,
    Uint8List photo,
    DateTime since,
  ) async {
    final repository = ref.read(nutritionRepositoryProvider);
    var result = await repository.startMealScan(id, photo);
    while (result.scan.status == MealScanStatus.pending) {
      await Future<void>.delayed(_every);
      if (_disposed) return null;
      if (DateTime.now().difference(since) > _patience) {
        return (
          scan: MealScan(
            id: id,
            status: MealScanStatus.failed,
            error: _failedMessage,
          ),
          source: result.source,
        );
      }
      result = await repository.mealScan(id);
    }
    return _disposed ? null : result;
  }

  static const _failedMessage =
      'L’analyse de la photo n’a pas abouti. Réessaie, ou saisis le repas à '
      'la main.';

  MealScanSeed? _fail(String message) {
    if (!_disposed) {
      state = (
        phase: MealScanPhase.failed,
        photo: state.photo,
        since: null,
        error: message,
      );
    }
    return null;
  }

  static String _messageFor(AppException error) => switch (error) {
    NetworkException() =>
      'Hors ligne : la photo s’analyse sur le serveur. Réessaie avec le '
          'réseau, ou saisis le repas à la main.',
    ForbiddenException() =>
      'Le scan d’assiette est réservé aux abonnés, comme le coach.',
    _ when error.fromApi && error.message.isNotEmpty => error.message,
    _ => _failedMessage,
  };
}

final mealScanControllerProvider =
    AutoDisposeNotifierProvider<MealScanController, MealScanView>(
      MealScanController.new,
    );
