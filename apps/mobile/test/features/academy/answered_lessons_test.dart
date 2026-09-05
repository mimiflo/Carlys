import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/data/answered_lessons_store.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/quiz_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UNE QUESTION, DEUX ENDROITS.
///
/// La question du jour paraît sur l'accueil ET dans sa catégorie de
/// l'Academy. Y répondre une fois doit se voir des deux côtés : sinon elle
/// semble revenir, et on la repose à quelqu'un qui vient d'y répondre.
void main() {
  const question = QuizQuestion(
    prompt: 'Quel faisceau du deltoïde donne la largeur d’épaules ?',
    choices: ['L’antérieur', 'Le latéral', 'Le postérieur'],
    answerIndex: 1,
    explanation: 'Le faisceau latéral écarte le bras du corps.',
  );

  group('mémoire des réponses', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('la PREMIÈRE réponse gagne : rouvrir ne réécrit rien', () async {
      // Un score dérivé compte les questions abordées : réécrire à chaque
      // ouverture ferait bouger le passé, et compter deux fois la même.
      const store = AnsweredLessonsStore();

      await store.markAnswered('anatomie-epaules', 2);
      await store.markAnswered('anatomie-epaules', 0);

      expect(await store.read(), {'anatomie-epaules': 2});
    });

    test('des préférences abîmées ne cassent pas l’Academy', () async {
      // Le pire d'une lecture ratée serait de reposer une question, pas de
      // faire échouer l'écran.
      SharedPreferences.setMockInitialValues({
        AnsweredLessonsStore.key: 'ceci n’est pas du JSON',
      });

      expect(await const AnsweredLessonsStore().read(), isEmpty);
    });
  });

  group('carte de quiz', () {
    Widget host(QuizCard card) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: card)),
    );

    testWidgets('une réponse venue d’ailleurs remplit la carte', (
      tester,
    ) async {
      // Le cas exact du bug : répondu sur l'accueil, la carte de l'Academy
      // doit s'ouvrir déjà remplie.
      await tester.pumpWidget(
        host(const QuizCard(question: question, answeredChoice: 2)),
      );
      await tester.pumpAndSettle();

      // L'explication ne s'affiche qu'une fois répondu.
      expect(find.text(question.explanation), findsOneWidget);
    });

    testWidgets('elle montre le choix RÉELLEMENT fait, pas le bon', (
      tester,
    ) async {
      // Afficher la bonne réponse sans montrer celle qui a été donnée
      // laisserait croire à une réussite après une erreur. Carlys ne
      // réécrit pas l'histoire du côté flatteur.
      await tester.pumpWidget(
        host(const QuizCard(question: question, answeredChoice: 2)),
      );
      await tester.pumpAndSettle();

      Color borderOf(String label) {
        final box = tester.widget<Container>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        );
        return ((box.decoration! as BoxDecoration).border! as Border).top.color;
      }

      expect(borderOf('Le postérieur'), AppColors.danger);
      expect(borderOf('Le latéral'), AppColors.success);
    });

    testWidgets('sans réponse connue, la question reste posée', (tester) async {
      await tester.pumpWidget(host(const QuizCard(question: question)));
      await tester.pumpAndSettle();

      expect(find.text(question.explanation), findsNothing);
    });

    testWidgets('répondre remonte l’index choisi ET sa justesse', (
      tester,
    ) async {
      // L'index est ce qui permet de rouvrir la carte à l'identique
      // ailleurs ; la justesse sert aux défis culturels.
      int? choice;
      bool? correct;

      await tester.pumpWidget(
        host(
          QuizCard(
            question: question,
            onAnswered: (index, isCorrect) {
              choice = index;
              correct = isCorrect;
            },
          ),
        ),
      );
      await tester.tap(find.text('Le latéral'));
      await tester.pumpAndSettle();

      expect(choice, 1);
      expect(correct, isTrue);
    });
  });
}
