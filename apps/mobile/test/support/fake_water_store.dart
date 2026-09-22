/// Compteur d'hydratation de test : en mémoire, pilotable.
///
/// LA SEULE doublure de [WaterStore] du dépôt. Il y en a eu deux pendant un
/// temps — celle-ci et une `InMemoryWaterStore` identique à 1 250 mL près —
/// et les faire diverger n'aurait profité à personne : le départ se passe
/// maintenant en paramètre.
///
/// Indispensable dans TOUT harnais qui monte l'accueil, et plus seulement
/// dans ceux qui affichent les mesures du jour : la maxime du jour lit
/// désormais les cibles d'aujourd'hui, donc l'eau. Sans doublure, le vrai
/// magasin Drift s'ouvre, arme son minuteur de minuit, et le test échoue sur
/// un minuteur pendant — après avoir laissé un fichier et une connexion
/// derrière lui.
library;

import 'dart:async';

import 'package:carlys_mobile/features/nutrition/domain/repositories/water_store.dart';

class FakeWaterStore implements WaterStore {
  /// Le paramètre est PUBLIC (`milliliters`) et le champ privé : Dart
  /// n'accepte pas de paramètre nommé privé, donc le formel d'initialisation
  /// que réclame la règle est impossible ici.
  // ignore: prefer_initializing_formals
  FakeWaterStore({int milliliters = 0}) : _milliliters = milliliters;

  int _milliliters;
  final StreamController<int> _controller = StreamController<int>.broadcast();

  int get milliliters => _milliliters;

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
