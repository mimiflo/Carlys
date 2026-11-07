import 'package:carlys_mobile/features/nutrition/domain/entities/glycemic_food.dart';
import 'package:carlys_mobile/features/nutrition/domain/glycemic_selection.dart';
import 'package:flutter_test/flutter_test.dart';

GlycemicFood _food(
  String name,
  int gi, {
  GlycemicCategory category = GlycemicCategory.fruits,
  GlycemicMark? mark,
}) => GlycemicFood(name: name, category: category, gi: gi, sem: 2, mark: mark);

void main() {
  group('classement bas, moyen, élevé', () {
    test('les bornes : 55 est bas, 56 et 69 moyens, 70 élevé', () {
      expect(GlycemicLevel.of(0), GlycemicLevel.low);
      expect(GlycemicLevel.of(55), GlycemicLevel.low);
      expect(GlycemicLevel.of(56), GlycemicLevel.medium);
      expect(GlycemicLevel.of(69), GlycemicLevel.medium);
      expect(GlycemicLevel.of(70), GlycemicLevel.high);
      expect(GlycemicLevel.of(103), GlycemicLevel.high);
    });

    test('la ligne se lit « Pomme crue, IG 36, bas. » et dit son renvoi', () {
      expect(_food('Pomme crue', 36).spoken(), 'Pomme crue, IG 36, bas.');
      expect(
        _food('Pomme crue', 36).spoken(withCategory: true),
        'Pomme crue, fruits, IG 36, bas.',
      );
      expect(
        _food(
          'Riz blanc bouilli',
          73,
          mark: GlycemicMark.lowGiVarieties,
        ).spoken(),
        'Riz blanc bouilli, IG 73, élevé. Des variétés à IG bas existent '
        'aussi.',
      );
    });
  });

  group('sélection', () {
    final foods = [
      _food('Pêches en conserve', 43),
      _food('Pastèque crue', 76),
      _food('Orge', 28, category: GlycemicCategory.breadsCereals),
      _food('Jus d’orange', 50),
      _food('Orange crue', 43),
    ];

    test('la recherche ignore casse et accents', () {
      expect(glycemicFoodsFor(foods, query: 'PECHE').map((f) => f.name), [
        'Pêches en conserve',
      ]);
      expect(glycemicFoodsFor(foods, query: '  '), hasLength(5));
      expect(glycemicFoodsFor(foods, query: 'kiwi'), isEmpty);
    });

    test('le filtre de famille, cumulé à la recherche', () {
      expect(
        glycemicFoodsFor(
          foods,
          category: GlycemicCategory.breadsCereals,
        ).map((f) => f.name),
        ['Orge'],
      );
      expect(
        glycemicFoodsFor(
          foods,
          query: 'orange',
          category: GlycemicCategory.breadsCereals,
        ),
        isEmpty,
      );
    });

    test('par famille : l’ordre du pack, sans rien trier', () {
      // Le pack est rangé famille par famille (sa garde le vérifie) : la
      // sélection n'a pas à le retrier.
      expect(glycemicFoodsFor(foods).map((f) => f.name), [
        'Pêches en conserve',
        'Pastèque crue',
        'Orge',
        'Jus d’orange',
        'Orange crue',
      ]);
    });

    test('par IG, croissant puis décroissant, stable à égalité', () {
      // Pêches et Orange ont toutes deux 43 : l'ordre du pack les départage.
      final asc = glycemicFoodsFor(foods, sort: GlycemicSort.ascending);
      expect(asc.map((f) => f.name), [
        'Orge',
        'Pêches en conserve',
        'Orange crue',
        'Jus d’orange',
        'Pastèque crue',
      ]);
      final desc = glycemicFoodsFor(foods, sort: GlycemicSort.descending);
      expect(desc.map((f) => f.name), [
        'Pastèque crue',
        'Jus d’orange',
        'Pêches en conserve',
        'Orange crue',
        'Orge',
      ]);
    });
  });
}
