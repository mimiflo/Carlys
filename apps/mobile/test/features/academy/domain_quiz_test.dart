import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/domain/academy_progress.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/controllers/academy_controllers.dart';
import 'package:carlys_mobile/features/academy/presentation/screens/domain_quiz_screen.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/academy_domain_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le quiz d'un domaine : une répétition qui ne note rien.
///
/// L'écran ne lit QUE le pack : aucune surcharge du magasin de réponses
/// n'est nécessaire pour ces tests, et c'est la preuve par construction que
/// le score ne s'écrit nulle part — un écran qui écrirait ferait échouer
/// ces montages, faute de stockage à disposition.
void main() {
  Lesson lecon(String id, {int answerIndex = 0}) => Lesson(
    id: id,
    category: AcademyCategory.hyrox,
    title: 'Leçon $id',
    body: 'corps',
    question: QuizQuestion(
      prompt: 'Question $id ?',
      choices: const ['Alpha', 'Beta', 'Gamma'],
      answerIndex: answerIndex,
      explanation: 'Explication $id.',
    ),
  );

  final pack = [
    lecon('hyrox-1'),
    lecon('hyrox-2', answerIndex: 1),
    Lesson(
      id: 'nutrition-1',
      category: AcademyCategory.nutrition,
      title: 'Hors domaine',
      body: 'corps',
      question: const QuizQuestion(
        prompt: 'Jamais posée ici ?',
        choices: ['a', 'b'],
        answerIndex: 0,
        explanation: 'e',
      ),
    ),
  ];

  Future<void> monter(WidgetTester tester, {String domaine = 'hyrox'}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [academyPackProvider.overrideWith((ref) async => pack)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: DomainQuizScreen(domaine: domaine),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('le quiz ne pose que les questions du domaine, une à la fois', (
    tester,
  ) async {
    await monter(tester);

    expect(find.text('Question 1 sur 2'), findsOneWidget);
    expect(find.text('Question hyrox-1 ?'), findsOneWidget);
    expect(find.text('Jamais posée ici ?'), findsNothing);
    // Pas de bouton tant qu'on n'a pas répondu : avancer sans lire n'existe
    // pas.
    expect(find.text('Question suivante'), findsNothing);
  });

  testWidgets('répondre montre l’explication puis ouvre le pas suivant', (
    tester,
  ) async {
    await monter(tester);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Explication hyrox-1.'), findsOneWidget);

    await tester.tap(find.text('Question suivante'));
    await tester.pumpAndSettle();
    expect(find.text('Question 2 sur 2'), findsOneWidget);
    // La carte suivante repart vierge : l'état « répondu » ne suit pas le
    // widget d'une question à l'autre.
    expect(find.text('Explication hyrox-2.'), findsNothing);
    expect(find.text('Voir le résultat'), findsNothing);
  });

  testWidgets('le score dit le compte, puis « Refaire » repart de zéro', (
    tester,
  ) async {
    await monter(tester);

    // Une bonne réponse, puis une mauvaise.
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Question suivante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gamma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir le résultat'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.textContaining('rien n’est enregistré'), findsOneWidget);

    await tester.tap(find.text('Refaire le quiz'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 sur 2'), findsOneWidget);
    expect(find.text('1 / 2'), findsNothing);
  });

  testWidgets('un domaine inconnu ou vide a son état vide, pas un plantage', (
    tester,
  ) async {
    await monter(tester, domaine: 'inexistant');
    expect(find.text('Rien à rejouer ici'), findsOneWidget);
  });

  group('l’affordance de l’en-tête', () {
    Future<void> monterEntete(
      WidgetTester tester, {
      required DomainProgress progress,
      VoidCallback? onQuiz,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: AcademyDomainHeader(
              category: AcademyCategory.hyrox,
              progress: progress,
              onQuiz: onQuiz,
            ),
          ),
        ),
      );
    }

    testWidgets('paraît sur un domaine bouclé, et ouvre le quiz', (
      tester,
    ) async {
      var ouvert = false;
      await monterEntete(
        tester,
        progress: const DomainProgress(abordees: 4, total: 4),
        onQuiz: () => ouvert = true,
      );

      await tester.tap(find.text('Quiz du domaine'));
      expect(ouvert, isTrue);
    });

    testWidgets('ne paraît PAS avant la fin du domaine', (tester) async {
      // Avant la fin, le quiz poserait des questions jamais lues : ce
      // serait un examen d'entrée, pas une répétition.
      await monterEntete(
        tester,
        progress: const DomainProgress(abordees: 3, total: 4),
        onQuiz: () {},
      );

      expect(find.text('Quiz du domaine'), findsNothing);
    });
  });
}
