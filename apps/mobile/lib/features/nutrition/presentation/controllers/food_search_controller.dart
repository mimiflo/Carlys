import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/utilities/debouncer.dart';
import '../../data/repositories/nutrition_repository_impl.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/meal_bounds.dart';

/// Où en est la recherche.
enum FoodSearchStatus {
  /// Moins de deux caractères : rien n'est demandé au serveur.
  idle,

  /// Une requête est partie ; les résultats précédents restent affichés.
  loading,

  /// La réponse est là (peut-être vide, peut-être d'une base vide).
  ready,

  /// Le réseau ou le serveur a manqué : l'écran propose de réessayer.
  failed,
}

/// Ce que la feuille « Ajouter un aliment » montre.
class FoodSearchState {
  const FoodSearchState({
    this.query = '',
    this.status = FoodSearchStatus.idle,
    this.foods = const [],
    this.source,
    this.error,
  });

  /// La recherche RETENUE (après l'anti-rebond), sans espaces de bord.
  final String query;
  final FoodSearchStatus status;

  /// Les résultats de la dernière réponse arrivée — gardés pendant la
  /// requête suivante, pour ne pas faire clignoter la liste à chaque mot.
  final List<Food> foods;

  /// La mention de la base (et sa version) donnée par la dernière réponse,
  /// `null` tant qu'aucune n'est arrivée.
  final FoodSource? source;
  final Object? error;

  /// La base n'est pas encore importée côté serveur (version nulle) : la
  /// saisie à la main est la seule voie, et la feuille le dit.
  bool get isDatabaseEmpty => source?.isEmpty ?? false;
}

/// La recherche d'aliments de la feuille « Ajouter un aliment ».
///
/// Deux gardes, parce qu'une recherche à la frappe sur le réseau d'une
/// cuisine en a besoin :
///
///  - **l'anti-rebond** ([Debouncer.search]) : « poulet » ne fait qu'une
///    requête, pas six ;
///  - **la génération** : chaque recherche porte un numéro, et une réponse
///    dont le numéro n'est plus le dernier est JETÉE. Une réponse lente à
///    « pou » ne remplace jamais celle, plus récente, de « poulet ».
class FoodSearchController extends AutoDisposeNotifier<FoodSearchState> {
  static final _logger = AppLogger('FoodSearch');

  final _debounce = Debouncer();
  int _generation = 0;
  bool _disposed = false;

  @override
  FoodSearchState build() {
    _disposed = false;
    ref.onDispose(() {
      _debounce.cancel();
      // Une réponse encore en vol quand la feuille se ferme tombe sans
      // bruit : poser `state` après la destruction jetterait.
      _disposed = true;
    });
    return const FoodSearchState();
  }

  /// À chaque frappe. Sous deux caractères, rien ne part, et une requête en
  /// vol est oubliée : sa réponse ne correspondrait plus au champ.
  void search(String text) {
    final query = text.trim();
    if (query.length < MealBounds.foodSearchMinLength) {
      _debounce.cancel();
      _generation++;
      state = FoodSearchState(source: state.source);
      return;
    }
    if (query == state.query && state.status != FoodSearchStatus.idle) {
      // Revenu au texte déjà cherché (« poule » puis « poulet » à nouveau) :
      // la réponse est là ou en route, et la frappe intermédiaire en
      // attente ne doit pas partir.
      _debounce.cancel();
      return;
    }
    _debounce.run(() => unawaited(_run(query)));
  }

  /// Relance la dernière recherche, tout de suite (« Réessayer »).
  Future<void> retry() {
    _debounce.cancel();
    return _run(state.query);
  }

  Future<void> _run(String query) async {
    if (_disposed || query.length < MealBounds.foodSearchMinLength) {
      return;
    }
    final generation = ++_generation;
    state = FoodSearchState(
      query: query,
      status: FoodSearchStatus.loading,
      foods: state.foods,
      source: state.source,
    );
    try {
      final result = await ref
          .read(nutritionRepositoryProvider)
          .searchFoods(query, limit: MealBounds.foodSearchLimit);
      if (_disposed || generation != _generation) {
        return; // dépassée par une recherche plus récente
      }
      state = FoodSearchState(
        query: query,
        status: FoodSearchStatus.ready,
        foods: result.foods,
        source: result.source,
      );
    } on Exception catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      _logger.warning('Recherche d’aliments en échec', error: error);
      state = FoodSearchState(
        query: query,
        status: FoodSearchStatus.failed,
        foods: state.foods,
        source: state.source,
        error: error,
      );
    }
  }
}

final foodSearchProvider =
    NotifierProvider.autoDispose<FoodSearchController, FoodSearchState>(
      FoodSearchController.new,
    );
