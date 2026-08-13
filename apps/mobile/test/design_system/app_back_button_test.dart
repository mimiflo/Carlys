import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La flèche de retour commune : elle dépile la page, et n'existe pas quand
/// il n'y a rien à dépiler — jamais de flèche morte.
void main() {
  testWidgets('sur une page poussée, la flèche apparaît et dépile',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: AppBackButton()),
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.back), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.byIcon(AppIcons.back), findsNothing);
  });

  testWidgets('à la racine, aucune flèche — rien à dépiler', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppBackButton())),
    );

    expect(find.byIcon(AppIcons.back), findsNothing);
  });
}
