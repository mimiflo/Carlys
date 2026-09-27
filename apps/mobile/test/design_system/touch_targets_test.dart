import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_composer.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_glass_button.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_library_header.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/onboarding_height_card.dart';
import 'package:carlys_mobile/features/workout_template/presentation/widgets/templates_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';
import '../support/fake_exercises_repository.dart';

/// Les cibles tactiles se MESURENT.
///
/// Trois boutons de l'application n'étaient pas des `IconButton` et ne
/// recevaient donc pas le rembourrage du thème : les flèches de taille de
/// l'onboarding (28), l'envoi du coach (40) et le bouton verre des fiches
/// (40) répondaient au doigt sur leur seul ornement. Chacun vit désormais
/// dans une boîte de [AppSpacing.touchTarget] ; ce fichier presse le COIN de
/// la boîte, là où l'ornement n'est pas, et attend une réponse.
void main() {
  // Les vraies polices : les hauteurs mesurées sont celles d'un téléphone.
  setUpAll(loadAppFonts);

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
      harness(
        CoachComposer(controller: controller, onSend: sent.add, onRetry: () {}),
      ),
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

  testWidgets('le champ du coach répond sur toute sa pilule', (tester) async {
    // Le champ était « dense », sans marge : 19 points de haut au milieu
    // d'une pilule de 43, dont le rembourrage ne transmettait pas le doigt.
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 360,
          child: CoachComposer(
            controller: controller,
            onSend: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    final champ = find.byType(TextField);
    expect(
      tester.getSize(champ).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
    final pilule = find
        .ancestor(of: champ, matching: find.byType(Container))
        .first;
    await tester.tapAt(corner(tester, pilule) + const Offset(20, 0));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('« Nouveau » des modèles fait 48 points de haut', (tester) async {
    var creations = 0;
    await tester.pumpWidget(
      harness(TemplatesHeader(onCreate: () => creations++)),
    );

    final bouton = find.ancestor(
      of: find.text('NOUVEAU'),
      matching: find.byType(GestureDetector),
    );
    expect(
      tester.getSize(bouton.first).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
    await tester.tapAt(corner(tester, bouton.first));
    expect(creations, 1);
  });

  testWidgets('le filtre de la bibliothèque fait la cible du design system', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exercisesRepositoryProvider.overrideWithValue(
            FakeExercisesRepository(const []),
          ),
        ],
        child: harness(const ExerciseLibraryHeader()),
      ),
    );

    final filtre = find.ancestor(
      of: find.byIcon(AppIcons.filter),
      matching: find.byType(GestureDetector),
    );
    expect(
      tester.getSize(filtre.first),
      const Size.square(AppSpacing.touchTarget),
    );
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

  testWidgets('une pastille INTERACTIVE répond au-delà de son ornement', (
    tester,
  ) async {
    // La pastille peinte fait 32 — c'est le dessin, et il ne change pas.
    // Sa boîte SENSIBLE, elle, déclarait aussi 32 : une constante rivale du
    // seul repère de cible tactile de l'application, que sept écrans
    // franchissent (filtres de progression, amorces du coach, séries prévues,
    // leçons, domaines d'académie, onglets de recettes).
    var presses = 0;
    await tester.pumpWidget(
      harness(AppPill(label: 'Semaine', onTap: () => presses++)),
    );

    final cible = find.ancestor(
      of: find.text('Semaine'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(cible).height, AppSpacing.touchTarget);

    // Le HAUT de la boîte : au-dessus de l'ornement, dans les huit dixièmes
    // transparents que `HitTestBehavior.opaque` rend sensibles.
    await tester.tapAt(tester.getRect(cible).topCenter + const Offset(0, 3));
    expect(presses, 1);
  });

  testWidgets('une pastille DÉCORATIVE ne gagne pas de cible', (tester) async {
    // Contre-épreuve : une pastille sans `onTap` est un ornement. Lui donner
    // 48 de haut gonflerait toutes les listes de badges de l'application pour
    // une zone que personne ne presse.
    await tester.pumpWidget(harness(const AppPill(label: '52 MIN')));

    expect(find.byType(GestureDetector), findsNothing);
    final hauteur = tester.getSize(find.byType(AppPill)).height;
    expect(hauteur, lessThan(AppSpacing.touchTarget));
  });
}
