import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les pièces des en-têtes de la refonte : le bouton-disque, et l'avatar à
/// l'initiale.
void main() {
  Widget monte(Widget child) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );

  group('AppRoundIconButton', () {
    testWidgets('le disque EST la cible tactile, et il répond', (tester) async {
      var appuis = 0;
      await tester.pumpWidget(
        monte(
          AppRoundIconButton(
            icon: AppIcons.search,
            tooltip: 'Rechercher',
            onPressed: () => appuis++,
          ),
        ),
      );

      final bouton = find.byType(AppRoundIconButton);
      expect(
        tester.getSize(bouton).shortestSide,
        greaterThanOrEqualTo(AppSpacing.touchTarget),
      );
      await tester.tap(bouton);
      expect(appuis, 1);
    });

    testWidgets('un bouton qui bascule se dit sélectionné tant qu’il dure', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        monte(
          AppRoundIconButton(
            icon: AppIcons.search,
            tooltip: 'Fermer la recherche',
            isActive: true,
            onPressed: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(AppRoundIconButton)),
        isSemantics(isSelected: true),
      );
      expect(find.byTooltip('Fermer la recherche'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('AppInitialAvatar', () {
    test('l’initiale : première lettre en capitale, « ? » pour un vide', () {
      expect(AppInitialAvatar.initialOf('camille'), 'C');
      expect(AppInitialAvatar.initialOf('  Élodie '), 'É');
      expect(AppInitialAvatar.initialOf('   '), '?');
      // Un graphème entier, jamais une demi-paire de substitution.
      expect(AppInitialAvatar.initialOf('👍 Tom'), '👍');
    });

    testWidgets('muet pour le lecteur d’écran : le prénom se dit à côté', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(monte(const AppInitialAvatar(name: 'Sarah')));

      expect(find.text('S'), findsOneWidget);
      expect(find.bySemanticsLabel('S'), findsNothing);
      semantics.dispose();
    });
  });
}
