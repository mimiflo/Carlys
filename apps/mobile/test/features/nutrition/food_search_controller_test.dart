import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/utilities/debouncer.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/food_search_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';
import '../../support/sample_meals.dart';

/// LA RECHERCHE D'ALIMENTS, sans écran : ce qui part au serveur, et ce qui
/// revient à l'écran.
///
/// Trois promesses : une frappe ne fait pas une requête (l'anti-rebond), une
/// réponse lente ne remplace pas une plus récente (la génération), et une
/// base vide se DIT (la saisie à la main reste la voie).
void main() {
  late FakeNutritionRepository nutrition;
  late ProviderContainer container;

  setUp(() {
    nutrition = FakeNutritionRepository()
      ..foods.addEntries(searchableFoods.map((f) => MapEntry(f.code, f)));
    container = ProviderContainer(
      overrides: [nutritionRepositoryProvider.overrideWithValue(nutrition)],
    );
    // Un auditeur garde le contrôleur (auto-disposé) en vie, comme la feuille.
    container.listen(foodSearchProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  FoodSearchController controller() =>
      container.read(foodSearchProvider.notifier);
  FoodSearchState state() => container.read(foodSearchProvider);

  test('la frappe est RETENUE : « poulet » tapé lettre à lettre fait UNE '
      'requête', () {
    fakeAsync((async) {
      for (final typed in ['p', 'po', 'pou', 'poul', 'poule', 'poulet']) {
        controller().search(typed);
        async.elapse(const Duration(milliseconds: 80));
      }
      expect(nutrition.searches, isEmpty, reason: 'rien avant le délai');

      async.elapse(Debouncer.search);
      async.flushMicrotasks();

      expect(nutrition.searches, ['poulet']);
      expect(state().status, FoodSearchStatus.ready);
      expect(state().foods.map((f) => f.shortName), ['Poulet']);
      expect(state().source?.version, '2020-07-07');
    });
  });

  test('sous deux caractères, rien ne part', () {
    fakeAsync((async) {
      controller().search(' r ');
      async.elapse(Debouncer.search * 2);
      async.flushMicrotasks();

      expect(nutrition.searches, isEmpty);
      expect(state().status, FoodSearchStatus.idle);
    });
  });

  test('une réponse LENTE ne remplace pas une plus récente', () {
    fakeAsync((async) {
      final slow = Completer<void>();
      nutrition.heldSearches['riz'] = slow;

      controller().search('riz');
      async.elapse(Debouncer.search);
      async.flushMicrotasks();
      expect(state().status, FoodSearchStatus.loading);

      controller().search('poulet');
      async.elapse(Debouncer.search);
      async.flushMicrotasks();
      expect(state().query, 'poulet');
      expect(state().foods.map((f) => f.shortName), ['Poulet']);

      // La réponse à « riz » arrive APRÈS : elle est jetée.
      slow.complete();
      async.flushMicrotasks();

      expect(nutrition.searches, ['riz', 'poulet']);
      expect(state().query, 'poulet');
      expect(state().status, FoodSearchStatus.ready);
      expect(state().foods.map((f) => f.shortName), ['Poulet']);
    });
  });

  test('effacer le champ oublie la requête en vol', () {
    fakeAsync((async) {
      final slow = Completer<void>();
      nutrition.heldSearches['riz'] = slow;
      controller().search('riz');
      async.elapse(Debouncer.search);
      async.flushMicrotasks();

      controller().search('');
      slow.complete();
      async.flushMicrotasks();

      expect(state().status, FoodSearchStatus.idle);
      expect(state().foods, isEmpty);
    });
  });

  test('pendant une nouvelle recherche, les résultats précédents restent', () {
    fakeAsync((async) {
      controller().search('riz');
      async.elapse(Debouncer.search);
      async.flushMicrotasks();
      final previous = state().foods;
      expect(previous, isNotEmpty);

      nutrition.heldSearches['riz complet'] = Completer<void>();
      controller().search('riz complet');
      async.elapse(Debouncer.search);
      async.flushMicrotasks();

      expect(state().status, FoodSearchStatus.loading);
      expect(state().foods, previous, reason: 'pas de liste qui clignote');
    });
  });

  test('une base VIDE (pas encore importée) se dit', () {
    fakeAsync((async) {
      nutrition.foods.clear();
      controller().search('poulet');
      async.elapse(Debouncer.search);
      async.flushMicrotasks();

      expect(state().status, FoodSearchStatus.ready);
      expect(state().foods, isEmpty);
      expect(state().isDatabaseEmpty, isTrue);
    });
  });

  test('un échec se dit, et « Réessayer » relance la même recherche', () {
    fakeAsync((async) {
      nutrition.searchFailure = const NetworkException('hors ligne');
      controller().search('brocoli');
      async.elapse(Debouncer.search);
      async.flushMicrotasks();

      expect(state().status, FoodSearchStatus.failed);
      expect(state().error, isA<NetworkException>());

      unawaited(controller().retry());
      async.flushMicrotasks();

      expect(nutrition.searches, ['brocoli', 'brocoli']);
      expect(state().status, FoodSearchStatus.ready);
      expect(state().foods.map((f) => f.shortName), ['Brocoli']);
    });
  });
}
