import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/domain/academy_journey.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_domain_sheet.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/journey_stepper.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/lesson_card.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/lesson_illustration.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/quiz_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La refonte de l'Academy (maquette d'octobre 2026), pièce par pièce : les
/// étapes du parcours, la feuille « Voir les 12 », les ronds à cocher du
/// quiz et la leçon repliée en vignette.
void main() {
  Widget monte(Widget enfant) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [enfant],
      ),
    ),
  );

  group('étapes du parcours', () {
    // Deux étapes lues, la troisième entamée, trois à venir.
    const progression = JourneyProgress(
      parEtape: [
        StageProgress(abordees: 4, total: 4),
        StageProgress(abordees: 5, total: 5),
        StageProgress(abordees: 1, total: 6),
        StageProgress(abordees: 0, total: 6),
        StageProgress(abordees: 0, total: 6),
        StageProgress(abordees: 0, total: 6),
      ],
      etapeCourante: 2,
      prochaineLecon: null,
    );

    List<BoxDecoration> pastilles(WidgetTester tester) => [
      for (final container in tester.widgetList<Container>(
        find.descendant(
          of: find.byType(JourneyStepper),
          matching: find.byType(Container),
        ),
      ))
        if (container.constraints?.maxWidth == JourneyStepper.dotSize)
          container.decoration! as BoxDecoration,
    ];

    testWidgets('cochées une fois lues, cerclée en cours, éteintes au-delà', (
      tester,
    ) async {
      await tester.pumpWidget(
        monte(const JourneyStepper(progress: progression)),
      );

      final dots = pastilles(tester);
      expect(dots, hasLength(6));
      expect(find.byIcon(AppIcons.check), findsNWidgets(2));
      for (final faite in dots.take(2)) {
        expect(faite.gradient, AppColors.violetRamp);
      }
      final enCours = dots[2].border! as Border;
      expect(enCours.top.color, AppColors.primaryLight);
      expect(enCours.top.width, greaterThan(1));
      for (final aVenir in dots.skip(3)) {
        expect(aVenir.gradient, isNull);
        expect((aVenir.border! as Border).top.color, AppColors.darkBorder);
      }
    });

    testWidgets('le trait se colore après chaque étape terminée', (
      tester,
    ) async {
      await tester.pumpWidget(
        monte(const JourneyStepper(progress: progression)),
      );

      final traits = [
        for (final container in tester.widgetList<Container>(
          find.descendant(
            of: find.descendant(
              of: find.byType(JourneyStepper),
              matching: find.byType(Expanded),
            ),
            matching: find.byType(Container),
          ),
        ))
          container.color,
      ];
      expect(traits, [
        AppColors.primaryLight,
        AppColors.primaryLight,
        AppColors.darkBorder,
        AppColors.darkBorder,
        AppColors.darkBorder,
      ]);
    });

    testWidgets('parcours terminé : six coches, aucune étape cerclée', (
      tester,
    ) async {
      await tester.pumpWidget(
        monte(
          JourneyStepper(
            progress: JourneyProgress(
              parEtape: [
                for (var i = 0; i < 6; i++)
                  const StageProgress(abordees: 3, total: 3),
              ],
              etapeCourante: null,
              prochaineLecon: null,
            ),
          ),
        ),
      );
      expect(find.byIcon(AppIcons.check), findsNWidgets(6));
      expect(pastilles(tester).map((pastille) => pastille.border), [
        for (var i = 0; i < 6; i++) isNull,
      ]);
    });
  });

  group('feuille « Voir les N »', () {
    const domaines = [
      AcademyCategory.nutrition,
      AcademyCategory.cardio,
      AcademyCategory.mental,
    ];
    int countOf(AcademyCategory domaine) =>
        domaine == AcademyCategory.cardio ? 1 : 4;

    Future<Future<AcademyCategory?>> ouvrir(WidgetTester tester) async {
      late Future<AcademyCategory?> choix;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => choix = pickAcademyDomain(
                  context,
                  domaines: domaines,
                  selected: AcademyCategory.nutrition,
                  countOf: countOf,
                ),
                child: const Text('Voir les 3'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Voir les 3'));
      await tester.pumpAndSettle();
      return choix;
    }

    testWidgets('chaque domaine dit son nombre de leçons, au singulier '
        'quand il n’en a qu’une', (tester) async {
      await ouvrir(tester);

      expect(find.text('Les 3 domaines'), findsOneWidget);
      expect(find.text('4 LEÇONS'), findsNWidgets(2));
      expect(find.text('1 LEÇON'), findsOneWidget);
    });

    testWidgets('toucher un domaine ferme la feuille et le rend', (
      tester,
    ) async {
      final choix = await ouvrir(tester);

      await tester.tap(find.text(AcademyCategory.mental.label));
      await tester.pumpAndSettle();

      expect(await choix, AcademyCategory.mental);
      expect(find.text('Les 3 domaines'), findsNothing);
    });

    testWidgets('le domaine affiché se dit sélectionné, pas seulement '
        'coché', (tester) async {
      final semantics = tester.ensureSemantics();
      await ouvrir(tester);

      expect(find.byIcon(AppIcons.check), findsOneWidget);
      expect(
        tester.getSemantics(find.text(AcademyCategory.nutrition.label)),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.text(AcademyCategory.cardio.label)),
        isSemantics(isSelected: false),
      );
      semantics.dispose();
    });
  });

  group('ronds à cocher du quiz', () {
    Widget choix({
      required bool picked,
      required bool correct,
      required bool answered,
      VoidCallback? onTap,
    }) => monte(
      QuizChoice(
        letter: 'B',
        label: 'Le latéral',
        picked: picked,
        correct: correct,
        answered: answered,
        onTap: onTap,
      ),
    );

    BoxDecoration rond(WidgetTester tester) =>
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                .decoration!
            as BoxDecoration;

    testWidgets('avant la réponse : un rond neutre, vide', (tester) async {
      await tester.pumpWidget(
        choix(picked: false, correct: true, answered: false),
      );

      expect(rond(tester).color, isNull);
      expect(
        (rond(tester).border! as Border).top.color,
        AppColors.quizLetterBorder,
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('choisi à tort : rond plein en rouge, et une croix', (
      tester,
    ) async {
      await tester.pumpWidget(
        choix(picked: true, correct: false, answered: true),
      );

      expect(rond(tester).color, AppColors.danger);
      expect(find.byIcon(AppIcons.close), findsOneWidget);
      expect(find.byIcon(AppIcons.check), findsNothing);
    });

    testWidgets('choisi à raison : rond plein en vert, et une coche', (
      tester,
    ) async {
      await tester.pumpWidget(
        choix(picked: true, correct: true, answered: true),
      );

      expect(rond(tester).color, AppColors.success);
      expect(find.byIcon(AppIcons.check), findsOneWidget);
    });

    testWidgets('la bonne réponse non choisie : cerclée de vert, jamais '
        'pleine — le plein ne va qu’au choix fait', (tester) async {
      await tester.pumpWidget(
        choix(picked: false, correct: true, answered: true),
      );

      expect(rond(tester).color, isNull);
      final cercle = rond(tester).border! as Border;
      expect(cercle.top.color, AppColors.success);
      expect(cercle.top.width, 2);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('le lecteur d’écran dit encore la lettre, l’état choisi, et '
        'peut répondre', (tester) async {
      final semantics = tester.ensureSemantics();
      var appuis = 0;
      await tester.pumpWidget(
        choix(
          picked: true,
          correct: false,
          answered: true,
          onTap: () => appuis++,
        ),
      );

      expect(
        tester.getSemantics(find.byType(QuizChoice)),
        isSemantics(
          label: 'B. Le latéral',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('B. Le latéral'));
      expect(appuis, 1);
      semantics.dispose();
    });
  });

  group('leçon repliée', () {
    const lecon = Lesson(
      id: 'nutrition-proteines',
      category: AcademyCategory.nutrition,
      title: 'Combien de protéines ?',
      body: 'Entre 1,6 et 2,2 g par kilo de poids de corps.',
      question: QuizQuestion(
        prompt: 'Quelle fourchette retenir ?',
        choices: ['0,8 g/kg', '1,6 à 2,2 g/kg', '4 g/kg'],
        answerIndex: 1,
        explanation: 'Au-delà, le gain devient négligeable.',
      ),
    );

    for (final (reponse, sousTitre) in const [
      (null, 'À lire, puis une question'),
      (1, 'Lue · question répondue'),
    ]) {
      testWidgets('${reponse == null ? 'sans' : 'avec'} réponse : '
          '« $sousTitre »', (tester) async {
        await tester.pumpWidget(
          monte(LessonCard(lesson: lecon, answeredChoice: reponse)),
        );
        expect(find.text(sousTitre), findsOneWidget);
      });
    }

    testWidgets('ouverte, la vignette laisse place à l’illustration '
        'entière ; refermée, elle revient', (tester) async {
      await tester.pumpWidget(monte(const LessonCard(lesson: lecon)));

      Iterable<double?> illustrations() => tester
          .widgetList<LessonIllustration>(find.byType(LessonIllustration))
          .map((illustration) => illustration.thumbnailSize);

      expect(illustrations(), [isNotNull]);
      expect(find.text(lecon.body), findsNothing);

      await tester.tap(find.text(lecon.title));
      await tester.pumpAndSettle();
      expect(illustrations(), [isNull]);
      expect(find.text(lecon.body), findsOneWidget);

      await tester.tap(find.text(lecon.title));
      await tester.pumpAndSettle();
      expect(illustrations(), [isNotNull]);
    });
  });
}
