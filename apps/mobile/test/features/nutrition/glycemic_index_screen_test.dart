import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/glycemic_food.dart';
import 'package:carlys_mobile/features/nutrition/presentation/providers/glycemic_index_providers.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/glycemic_index_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'écran du tableau : recherche, filtre par famille, tri par IG, et une
/// ligne qui se lit d'un trait au lecteur d'écran.
///
/// Le pack est surchargé par quelques aliments fixes : ce test éprouve
/// l'écran ; l'exactitude des valeurs a sa propre garde.
const _pack = [
  GlycemicFood(
    name: 'Riz blanc bouilli',
    category: GlycemicCategory.breadsCereals,
    gi: 73,
    sem: 4,
    mark: GlycemicMark.lowGiVarieties,
  ),
  GlycemicFood(
    name: 'Orge',
    category: GlycemicCategory.breadsCereals,
    gi: 28,
    sem: 2,
  ),
  GlycemicFood(
    name: 'Pomme crue',
    category: GlycemicCategory.fruits,
    gi: 36,
    sem: 2,
    mark: GlycemicMark.allDataAverage,
  ),
  GlycemicFood(
    name: 'Ananas cru',
    category: GlycemicCategory.fruits,
    gi: 59,
    sem: 8,
  ),
];

Widget _app({Future<List<GlycemicFood>> Function()? load}) => ProviderScope(
  overrides: [
    glycemicIndexPackProvider.overrideWith(
      (ref) => load == null ? Future.value(_pack) : load(),
    ),
  ],
  child: const MaterialApp(home: GlycemicIndexScreen()),
);

/// Un téléphone haut : les quatre lignes tiennent sous l'explication.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// La liste verticale, et non la rangée de pastilles qui défile de côté.
final _list = find.byType(Scrollable).first;

/// Les noms des lignes, dans l'ordre de l'écran.
List<String> _names(WidgetTester tester) => [
  for (final row in tester.widgetList<AppListRow>(find.byType(AppListRow)))
    row.title,
];

void main() {
  testWidgets('l’explication, la source et le tableau par famille', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Ce que l’IG mesure'), findsOneWidget);
    expect(find.textContaining('pas un avis médical'), findsOneWidget);
    expect(find.textContaining('charge glycémique'), findsOneWidget);
    expect(_names(tester), [
      'Riz blanc bouilli *',
      'Orge',
      'Pomme crue †',
      'Ananas cru',
    ]);
    expect(find.text('PAINS ET CÉRÉALES'), findsOneWidget);
    expect(find.text('FRUITS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('doi:10.2337/dc08-1239'),
      200,
      scrollable: _list,
    );
    expect(find.textContaining('Atkinson FS'), findsOneWidget);
    expect(
      find.text('* Des variétés à IG bas existent aussi.'),
      findsOneWidget,
    );
    expect(
      find.text('† Moyenne de toutes les données publiées.'),
      findsOneWidget,
    );
  });

  testWidgets('chaque ligne se lit « Pomme crue, IG 36, bas. »', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Pomme crue, IG 36, bas. Moyenne de toutes les données publiées.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Ananas cru, IG 59, moyen.'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('PAINS ET CÉRÉALES')),
      matchesSemantics(label: 'PAINS ET CÉRÉALES', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('la recherche, puis son état vide', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'POMME');
    await tester.pump();
    expect(_names(tester), ['Pomme crue †']);

    await tester.enterText(find.byType(TextField), 'kiwi');
    await tester.pump();
    expect(_names(tester), isEmpty);
    expect(find.text('Aucun aliment trouvé'), findsOneWidget);
    expect(find.textContaining('4 aliments courants'), findsOneWidget);

    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pump();
    expect(_names(tester), hasLength(4));
  });

  testWidgets('le filtre par famille, et le tri par IG', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // La quatrième pastille dépasse du bord : on la fait défiler d'abord.
    await tester.ensureVisible(find.text('Fruits'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fruits'));
    await tester.pump();
    expect(_names(tester), ['Pomme crue †', 'Ananas cru']);

    await tester.tap(find.bySemanticsLabel('IG décroissant'));
    await tester.pump();
    expect(_names(tester), ['Ananas cru', 'Pomme crue †']);

    await tester.ensureVisible(find.text('Tous'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tous'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('IG croissant'));
    await tester.pump();
    expect(_names(tester), [
      'Orge',
      'Pomme crue †',
      'Ananas cru',
      'Riz blanc bouilli *',
    ]);
    // Les familles se mêlent : la ligne dit la sienne, les titres partent.
    expect(find.text('FRUITS · ± 2'), findsOneWidget);
    expect(find.text('PAINS ET CÉRÉALES'), findsNothing);
  });

  testWidgets('un échec de lecture se reprend', (tester) async {
    _tall(tester);
    var appels = 0;
    await tester.pumpWidget(
      _app(
        load: () async {
          appels++;
          if (appels == 1) {
            throw const FormatException('pack illisible');
          }
          return _pack;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tableau indisponible'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(_names(tester), hasLength(4));
  });

  testWidgets('au texte agrandi, rien ne déborde', (tester) async {
    // 320 points de large, texte à 200 %.
    tester.view.physicalSize = const Size(960, 2000);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    _tall(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Ananas cru'),
      300,
      scrollable: _list,
    );
    expect(tester.takeException(), isNull);
  });
}
