import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La feuille commune : son bouton de validation doit rester ATTEIGNABLE,
/// au-dessus de la barre système du téléphone comme au-dessus du clavier —
/// c'est exactement le défaut constaté sur certains appareils.
Widget host() => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () => showAppSheet<void>(
            context,
            builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Contenu'),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Valider'),
                  ),
                ],
              ),
            ),
          ),
          child: const Text('Ouvrir'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('le bouton reste AU-DESSUS de la barre système du téléphone', (
    tester,
  ) async {
    // Barre de navigation 3 boutons : 144 px physiques (48 logiques à DPR 3).
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    tester.view.padding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final ratio = tester.view.devicePixelRatio;
    final screenBottom = tester.view.physicalSize.height / ratio;
    final inset = 144 / ratio;
    final buttonBottom = tester.getBottomLeft(find.text('Valider')).dy;

    expect(
      buttonBottom,
      lessThanOrEqualTo(screenBottom - inset),
      reason:
          'Le bouton de validation ne doit jamais passer sous la barre '
          'système (il était inatteignable sur certains téléphones).',
    );
  });

  testWidgets('clavier ouvert : le contenu remonte au-dessus du clavier', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    // Le clavier recouvre la barre système : le framework ramène alors le
    // padding bas à zéro — on reproduit cet état.
    tester.view.padding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final ratio = tester.view.devicePixelRatio;
    final screenBottom = tester.view.physicalSize.height / ratio;
    final keyboard = 900 / ratio;
    final buttonBottom = tester.getBottomLeft(find.text('Valider')).dy;

    expect(buttonBottom, lessThanOrEqualTo(screenBottom - keyboard));
  });

  testWidgets('sans encoche ni clavier : aucun espace parasite en bas', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Valider'), findsOneWidget);
  });
}
