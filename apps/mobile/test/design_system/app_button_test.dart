import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('déclenche onPressed au tap', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        _wrap(AppButton(label: 'Valider', onPressed: () => pressed = true)),
      );

      await tester.tap(find.text('Valider'));
      expect(pressed, isTrue);
    });

    testWidgets('est désactivé quand onPressed est null', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Valider', onPressed: null)),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('en chargement : bouton désactivé et indicateur visible', (
      tester,
    ) async {
      var pressed = false;

      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Valider',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Valider'), findsNothing);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(pressed, isFalse);
    });

    testWidgets('l’action principale porte le MÊME dégradé que le login', (
      tester,
    ) async {
      // Le bouton primaire n'est plus un violet plat : il reprend le dégradé
      // des écrans d'entrée (AppColors.cta), pour que « Valider » ici et
      // « Se connecter » là parlent la même couleur. La garde suit le
      // dégradé, pas un ton isolé.
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Valider', onPressed: _noop)),
      );

      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<LinearGradient>();

      expect(
        gradients,
        contains(AppColors.cta),
        reason: 'le fond du bouton primaire doit être le dégradé cta du login',
      );
    });

    testWidgets('désactivée, l’action principale s’éteint (fond ET texte)', (
      tester,
    ) async {
      // Un dégradé plein sous un libellé grisé se lirait comme un bug : tout
      // pâlit d'un même mouvement via une opacité d'ensemble.
      await tester.pumpWidget(
        _wrap(const AppButton(label: 'Valider', onPressed: null)),
      );

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(FilledButton),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, lessThan(1));
    });

    testWidgets('la variante destructive peint le rouge de remplissage', (
      tester,
    ) async {
      // `dangerStrong`, pas `danger` : blanc sur `danger` ne tient que
      // 3,76:1 (la contre-épreuve de lisibilité est dans app_colors_test).
      await tester.pumpWidget(
        _wrap(
          const AppButton(
            label: 'Supprimer',
            variant: AppButtonVariant.destructive,
            onPressed: _noop,
          ),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final background = button.style?.backgroundColor?.resolve(
        <WidgetState>{},
      );
      expect(background, AppColors.dangerStrong);
    });
  });

  group('AppBrandButton', () {
    testWidgets('s’active depuis un lecteur d’écran, pas seulement au doigt', (
      tester,
    ) async {
      // Le bouton est peint et touché par un GestureDetector, invisible à la
      // couche d'accessibilité : c'est le nœud Semantics au-dessus qui doit
      // porter l'action. S'annoncer « bouton » sans publier de tap est pire
      // que de ne rien annoncer — on promet une commande qui ne répond pas.
      final handle = tester.ensureSemantics();
      var pressed = 0;

      await tester.pumpWidget(
        _wrap(AppBrandButton(label: 'Commencer', onPressed: () => pressed++)),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Commencer')),
        isSemantics(label: 'Commencer', isButton: true, hasTapAction: true),
      );

      tester.semantics.tap(find.semantics.byLabel('Commencer'));
      await tester.pump();

      expect(pressed, 1);
      handle.dispose();
    });
  });
}

void _noop() {}
