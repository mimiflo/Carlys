import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_composer.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_glass_button.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/onboarding_height_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les cibles tactiles se MESURENT.
///
/// Trois boutons de l'application n'étaient pas des `IconButton` et ne
/// recevaient donc pas le rembourrage du thème : les flèches de taille de
/// l'onboarding (28), l'envoi du coach (40) et le bouton verre des fiches
/// (40) répondaient au doigt sur leur seul ornement. Chacun vit désormais
/// dans une boîte de [AppSpacing.touchTarget] ; ce fichier presse le COIN de
/// la boîte, là où l'ornement n'est pas, et attend une réponse.
void main() {
  Widget harness(Widget child) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );

  /// Un point de la boîte tactile hors de l'ornement centré.
  Offset corner(WidgetTester tester, Finder box) =>
      tester.getRect(box).topLeft + const Offset(3, 3);

  test('le minimum Material et le token disent la même chose', () {
    // Les `IconButton` sont rembourrés par Flutter à kMinInteractiveDimension,
    // les autres boutons par le token : si l'un bouge sans l'autre, deux
    // tailles de cible coexistent à nouveau.
    expect(kMinInteractiveDimension, AppSpacing.touchTarget);
  });

  testWidgets('les flèches de taille répondent sur toute la boîte', (
    tester,
  ) async {
    final changes = <double>[];
    await tester.pumpWidget(
      harness(
        OnboardingHeightCard(
          heightCm: 175,
          touched: false,
          onChanged: changes.add,
        ),
      ),
    );

    final plus = find.ancestor(
      of: find.byIcon(AppIcons.add),
      matching: find.byType(GestureDetector),
    );
    final size = tester.getSize(plus);
    expect(size.width, greaterThanOrEqualTo(AppSpacing.touchTarget));
    expect(size.height, greaterThanOrEqualTo(AppSpacing.touchTarget));

    await tester.tapAt(corner(tester, plus));
    expect(changes, [176]);
  });

  testWidgets('l’envoi du coach répond au-delà de son disque', (tester) async {
    final sent = <String>[];
    final controller = TextEditingController(text: 'Combien de séries ?');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(CoachComposer(controller: controller, onSend: sent.add)),
    );

    final send = find.ancestor(
      of: find.byIcon(AppIcons.send),
      matching: find.byType(GestureDetector),
    );
    final size = tester.getSize(send);
    expect(size.width, greaterThanOrEqualTo(AppSpacing.touchTarget));
    expect(size.height, greaterThanOrEqualTo(AppSpacing.touchTarget));

    await tester.tapAt(corner(tester, send));
    expect(sent, ['Combien de séries ?']);
  });

  testWidgets('le bouton verre répond au-delà de son ornement', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      harness(
        ExerciseGlassButton(
          icon: AppIcons.back,
          semanticLabel: 'Retour',
          onPressed: () => pressed++,
        ),
      ),
    );

    final button = find.byType(ExerciseGlassButton);
    expect(tester.getSize(button), const Size.square(AppSpacing.touchTarget));
    // L'ornement, lui, garde ses 40 points au centre.
    final ornament = find.descendant(
      of: button,
      matching: find.byType(BackdropFilter),
    );
    expect(
      tester.getSize(ornament),
      const Size.square(ExerciseGlassButton.ornamentSize),
    );
    expect(tester.getCenter(ornament), tester.getCenter(button));

    await tester.tapAt(corner(tester, button));
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets('la flèche de retour occupe la boîte tactile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
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

    // Les CONTRAINTES du bouton, pas sa taille rendue : le rembourrage
    // `MaterialTapTargetSize.padded` du thème portait déjà une boîte de 44
    // à 48 à l'écran — la taille rendue passait donc AVANT le correctif et
    // ne défendait rien. La boîte déclarée, elle, doit être le token.
    final button = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(AppBackButton),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      button.constraints,
      const BoxConstraints.tightFor(
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
      ),
    );
  });
}
