import 'dart:convert';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE CONTRAT HTTP DES REPAS ET DES ALIMENTS, figé sans serveur.
///
/// Ce que ce fichier protège, d'abord : un repas COMPOSÉ ne part JAMAIS avec
/// ses totaux. Le serveur refuse en 400 un corps qui porterait des aliments
/// ET des calories, même à `null` — pour qu'aucun des deux ne soit ignoré
/// en silence. Les corps sont donc comparés EN ENTIER, clé par clé : une clé
/// de trop est une faute, pas un détail.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody _enveloped(Object data, {Object meta = const {}}) =>
    _json(200, {'data': data, 'meta': meta, 'requestId': 'test'});

const _source = {
  'attribution':
      'Source : Anses, Table de composition nutritionnelle des aliments '
      'Ciqual',
  'license': 'Licence Ouverte Etalab 2.0',
  'url': 'https://ciqual.anses.fr/',
};

/// Le repas de la maquette, tel que le serveur le rend.
Map<String, Object?> _composedRow() => {
  'id': 'repas-1',
  'name': 'Poulet, riz, brocoli',
  'moment': 'LUNCH',
  'kcal': 390,
  'quantity': 320,
  'quantityUnit': 'GRAM',
  'proteinG': 40,
  'carbsG': 44,
  'fatG': 5,
  'eatenAt': '2026-09-25T10:30:00.000Z',
  'components': [
    {
      'id': 'ligne-poulet',
      'foodCode': 990001,
      'name': 'Poulet, filet, sans peau, cuit',
      'shortName': 'Poulet',
      'group': 'viandes, œufs, poissons et assimilés',
      'sourceVersion': '2020-07-07',
      'quantityG': 120,
      'kcal': 180,
      'proteinG': 34.8,
      'carbsG': 0,
      'fatG': 4.3,
    },
  ],
  'computed': true,
  'photo': {'updatedAt': '2026-09-25T10:40:00.000Z'},
};

void main() {
  late Dio dio;
  late NutritionRepositoryImpl repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
    repository = NutritionRepositoryImpl(dio);
  });

  _RecordingAdapter record(ResponseBody Function(RequestOptions) respond) {
    final adapter = _RecordingAdapter(respond);
    dio.httpClientAdapter = adapter;
    return adapter;
  }

  final eatenAt = DateTime.utc(2026, 9, 25, 10, 30);

  group('lire', () {
    test(
      'un repas : GET /nutrition/meals/:id, aliments, photo, mention',
      () async {
        final adapter = record(
          (_) => _enveloped(_composedRow(), meta: {'source': _source}),
        );

        final detail = await repository.meal('repas-1');

        final request = adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.path, '/nutrition/meals/repas-1');
        final meal = detail.meal;
        expect(meal.moment, MealMoment.lunch);
        expect(meal.computed, isTrue);
        expect(meal.photoUpdatedAt, DateTime.utc(2026, 9, 25, 10, 40));
        final poulet = meal.components.single;
        expect(poulet.id, 'ligne-poulet');
        expect(poulet.foodCode, 990001);
        expect(poulet.shortName, 'Poulet');
        expect(poulet.sourceVersion, '2020-07-07');
        expect(poulet.quantityG, 120);
        expect(poulet.proteinG, 34.8);
        expect(detail.attribution?.license, 'Licence Ouverte Etalab 2.0');
      },
    );

    test('un serveur plus ANCIEN : ni moment, ni aliments, ni photo', () async {
      // La liste d'avant la composition : les clés manquent, elles ne sont
      // pas nulles. Rien ne doit casser, et rien ne doit s'inventer.
      record(
        (_) => _enveloped([
          {
            'id': 'repas-ancien',
            'name': 'Omelette',
            'kcal': 420,
            'quantity': null,
            'quantityUnit': null,
            'proteinG': 24,
            'carbsG': null,
            'fatG': null,
            'eatenAt': '2026-09-20T18:00:00.000Z',
          },
        ]),
      );

      final meal = (await repository.mealsBetween(eatenAt, eatenAt)).single;

      expect(meal.moment, isNull);
      expect(meal.components, isEmpty);
      expect(meal.computed, isFalse);
      expect(meal.hasPhoto, isFalse);
      expect(meal.carbsG, isNull, reason: 'inconnu, pas zéro');
    });

    test(
      'un serveur plus RÉCENT : un moment inconnu se lit « aucun »',
      () async {
        record(
          (_) => _enveloped({
            ..._composedRow(),
            'moment': 'BRUNCH',
            'components': <Object>[],
            'computed': false,
          }),
        );

        final meal = (await repository.meal('repas-1')).meal;

        // L'écran le proposera d'après l'heure plutôt que d'en afficher un
        // faux.
        expect(meal.moment, isNull);
        expect(meal.displayedMoment, isNotNull);
      },
    );

    test('un repas introuvable : le 404 du serveur, tel quel', () async {
      record(
        (_) => _json(404, {
          'error': {
            'code': 'NOT_FOUND',
            'message': 'Repas introuvable.',
            'details': null,
            'requestId': 'test',
          },
        }),
      );

      await expectLater(
        repository.meal('parti'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statut', 404),
        ),
      );
    });
  });

  group('créer', () {
    test('saisi à la main : les calories, la paire, et RIEN de nul', () async {
      final adapter = record((_) => _enveloped(_composedRow()));

      await repository.addMeal(
        'uuid-neuf',
        MealWrite(
          name: 'Skyr, granola',
          moment: MealMoment.breakfast,
          eatenAt: eatenAt,
          content: const ManualMealContent(
            kcal: 380,
            proteinG: 28,
            quantity: 1.5,
            quantityUnit: MealQuantityUnit.portion,
          ),
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/nutrition/meals');
      expect(request.data, {
        'id': 'uuid-neuf',
        'name': 'Skyr, granola',
        'moment': 'BREAKFAST',
        'eatenAt': '2026-09-25T10:30:00.000Z',
        'kcal': 380,
        'quantity': 1.5,
        'quantityUnit': 'PORTION',
        'proteinG': 28,
      });
    });

    test(
      'composé : les lignes {id, foodCode, quantityG}, AUCUN total',
      () async {
        final adapter = record((_) => _enveloped(_composedRow()));

        await repository.addMeal(
          'uuid-neuf',
          MealWrite(
            name: 'Poulet, riz, brocoli',
            moment: MealMoment.lunch,
            eatenAt: eatenAt,
            content: const ComposedMealContent([
              MealComponentInput(
                id: 'ligne-1',
                foodCode: 990001,
                quantityG: 120,
              ),
              MealComponentInput(
                id: 'ligne-2',
                foodCode: 990002,
                quantityG: 150.5,
              ),
            ]),
          ),
        );

        expect(adapter.requests.single.data, {
          'id': 'uuid-neuf',
          'name': 'Poulet, riz, brocoli',
          'moment': 'LUNCH',
          'eatenAt': '2026-09-25T10:30:00.000Z',
          'components': [
            {'id': 'ligne-1', 'foodCode': 990001, 'quantityG': 120.0},
            {'id': 'ligne-2', 'foodCode': 990002, 'quantityG': 150.5},
          ],
        });
      },
    );
  });

  group('corriger', () {
    MealWrite write(MealContent content) => MealWrite(
      name: 'Poulet, riz',
      moment: MealMoment.dinner,
      eatenAt: eatenAt,
      content: content,
    );

    test(
      'saisi : TOUTES les clés, nulles comprises, sans composition',
      () async {
        final adapter = record((_) => _enveloped(_composedRow()));

        await repository.updateMeal(
          'repas-1',
          write(const ManualMealContent(kcal: 650, carbsG: 80)),
        );

        final request = adapter.requests.single;
        expect(request.method, 'PATCH');
        expect(request.path, '/nutrition/meals/repas-1');
        // Une case vidée veut dire « on ne sait plus » : seul un null
        // explicite l'écrit. Et pas de `components` : un repas saisi le reste.
        expect(request.data, {
          'name': 'Poulet, riz',
          'moment': 'DINNER',
          'eatenAt': '2026-09-25T10:30:00.000Z',
          'kcal': 650,
          'quantity': null,
          'quantityUnit': null,
          'proteinG': null,
          'carbsG': 80,
          'fatG': null,
        });
      },
    );

    test(
      'le dernier aliment retiré : `components: []` et les totaux',
      () async {
        final adapter = record((_) => _enveloped(_composedRow()));

        await repository.updateMeal(
          'repas-1',
          write(
            const ManualMealContent(
              kcal: 390,
              proteinG: 40,
              carbsG: 44,
              fatG: 5,
              quantity: 320,
              quantityUnit: MealQuantityUnit.gram,
              clearsComposition: true,
            ),
          ),
        );

        expect(adapter.requests.single.data, {
          'name': 'Poulet, riz',
          'moment': 'DINNER',
          'eatenAt': '2026-09-25T10:30:00.000Z',
          'kcal': 390,
          'quantity': 320.0,
          'quantityUnit': 'GRAM',
          'proteinG': 40,
          'carbsG': 44,
          'fatG': 5,
          'components': <Object>[],
        });
      },
    );

    test('recomposé : la liste remplace, sans un seul total', () async {
      final adapter = record((_) => _enveloped(_composedRow()));

      await repository.updateMeal(
        'repas-1',
        write(
          const ComposedMealContent([
            MealComponentInput(
              id: 'ligne-poulet',
              foodCode: 990001,
              quantityG: 200,
            ),
          ]),
        ),
      );

      expect(adapter.requests.single.data, {
        'name': 'Poulet, riz',
        'moment': 'DINNER',
        'eatenAt': '2026-09-25T10:30:00.000Z',
        'components': [
          {'id': 'ligne-poulet', 'foodCode': 990001, 'quantityG': 200.0},
        ],
      });
    });

    test(
      'composition gardée : le nom, le moment, l’heure, et rien d’autre',
      () async {
        final adapter = record((_) => _enveloped(_composedRow()));

        await repository.updateMeal(
          'repas-1',
          write(const KeptCompositionContent()),
        );

        expect(adapter.requests.single.data, {
          'name': 'Poulet, riz',
          'moment': 'DINNER',
          'eatenAt': '2026-09-25T10:30:00.000Z',
        });
      },
    );
  });

  group('la base d’aliments', () {
    test(
      'chercher : ?q=&limit=, valeurs pour 100 g, mention et version',
      () async {
        final adapter = record(
          (_) => _enveloped(
            [
              {
                'code': 990006,
                'name': 'Galette de riz soufflé, nature',
                'shortName': 'Galette de riz soufflé',
                'group': 'produits céréaliers',
                'per100g': {
                  'kcal': 390,
                  'proteinG': 8,
                  'carbsG': 81,
                  'fatG': null,
                },
              },
            ],
            meta: {
              'source': {..._source, 'version': '2020-07-07'},
            },
          ),
        );

        final result = await repository.searchFoods('riz', limit: 5);

        final request = adapter.requests.single;
        expect(request.path, '/nutrition/foods');
        expect(request.queryParameters, {'q': 'riz', 'limit': 5});
        final galette = result.foods.single;
        expect(galette.code, 990006);
        expect(galette.per100g.kcal, 390);
        expect(galette.per100g.fatG, isNull, reason: 'la table ne le dit pas');
        expect(galette.family, FoodFamily.cereals);
        expect(result.source.version, '2020-07-07');
        expect(result.source.isEmpty, isFalse);
      },
    );

    test(
      'une base pas encore chargée : aucune version, aucun aliment',
      () async {
        record(
          (_) => _enveloped(
            <Object>[],
            meta: {
              'source': {..._source, 'version': null},
            },
          ),
        );

        final result = await repository.searchFoods('poulet');

        expect(result.foods, isEmpty);
        expect(result.source.isEmpty, isTrue);
      },
    );

    test('la fiche : GET /nutrition/foods/:code', () async {
      final adapter = record(
        (_) => _enveloped(
          {
            'code': 990001,
            'name': 'Poulet, filet, sans peau, cuit',
            'shortName': 'Poulet',
            'group': 'viandes, œufs, poissons et assimilés',
            'per100g': {'kcal': 150, 'proteinG': 29, 'carbsG': 0, 'fatG': 3.6},
          },
          meta: {
            'source': {..._source, 'version': '2020-07-07'},
          },
        ),
      );

      final detail = await repository.food(990001);

      expect(adapter.requests.single.path, '/nutrition/foods/990001');
      expect(detail.food.shortName, 'Poulet');
      expect(detail.food.family, FoodFamily.proteins);
      expect(detail.source.version, '2020-07-07');
    });
  });
}
