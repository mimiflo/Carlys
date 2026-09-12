/// Compteur d'eau EN MÉMOIRE — doublure de test, aucun Drift.
///
/// Sans elle, un harnais qui monte l'accueil ouvre un vrai flux Drift sur la
/// base en mémoire (`consumedWaterTodayProvider` → `LocalWaterStore`), et sa
/// fermeture au démontage planifie un minuteur qui survit au test :
/// « A Timer is still pending » sur toute la suite. Le compteur démarre à
/// mi-parcours pour que la jauge de l'accueil montre autre chose que zéro.
library;

import 'dart:async';

import 'package:carlys_mobile/features/nutrition/presentation/controllers/water_controllers.dart';

class InMemoryWaterStore implements WaterStore {
  final StreamController<int> _controller = StreamController<int>.broadcast();
  int _milliliters = 1250;

  @override
  Stream<int> watchToday() async* {
    yield _milliliters;
    yield* _controller.stream;
  }

  @override
  Future<int> addToday(int milliliters) async {
    _milliliters = (_milliliters + milliliters).clamp(0, 20000);
    _controller.add(_milliliters);
    return _milliliters;
  }
}
