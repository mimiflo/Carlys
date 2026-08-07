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
        _wrap(
          AppButton(
            label: 'Valider',
            onPressed: () => pressed = true,
          ),
        ),
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

    testWidgets('en chargement : bouton désactivé et indicateur visible',
        (tester) async {
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

    testWidgets('la variante destructive utilise la couleur d’erreur',
        (tester) async {
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
      final background =
          button.style?.backgroundColor?.resolve(<WidgetState>{});
      expect(background, AppColors.danger);
    });
  });
}

void _noop() {}
