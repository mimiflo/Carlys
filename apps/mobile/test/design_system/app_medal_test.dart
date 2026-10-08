import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// LA MÉDAILLE : en métal une fois gagnée, éteinte sous cadenas avant — ce
/// qui reste à gagner se voit, sans ressembler à un échec.
void main() {
  Future<BoxDecoration> monte(WidgetTester tester, AppMedalMetal? metal) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: AppMedal(metal: metal)),
      ),
    );
    return tester
            .widget<Container>(
              find.descendant(
                of: find.byType(AppMedal),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;
  }

  testWidgets('sans métal : un disque éteint et un cadenas, aucun dégradé', (
    tester,
  ) async {
    final disque = await monte(tester, null);

    expect(disque.gradient, isNull);
    expect(disque.color, AppColors.darkSurfaceAlt);
    expect(find.byIcon(AppIcons.lock), findsOneWidget);
    expect(find.byIcon(AppIcons.rank), findsNothing);
  });

  for (final metal in AppMedalMetal.values) {
    testWidgets('en ${metal.name} : le dégradé de son métal et la médaille '
        'gravée dans sa teinte sombre', (tester) async {
      final disque = await monte(tester, metal);

      expect((disque.gradient! as LinearGradient).colors, [
        metal.light,
        metal.base,
        metal.dark,
      ]);
      expect(find.byIcon(AppIcons.lock), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.rank)).color, metal.dark);
    });
  }
}
