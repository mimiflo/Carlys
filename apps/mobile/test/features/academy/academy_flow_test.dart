import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/lesson_card.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/quiz_card.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/selected_group_bar.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_community_repository.dart';
import '../../support/fake_exercises_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';

/// L'Academy dans l'application : leçons par domaine, question du jour,
/// quiz qui enseigne (l'explication s'affiche juste ou faux).
Widget app({FakeCommunityRepository? community}) => ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(storedSession: true)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        exercisesRepositoryProvider.overrideWithValue(
          FakeExercisesRepository([
            summary('e1', 'Développé couché', group: 'pectoraux'),
            summary('e2', 'Écarté haltères', group: 'pectoraux'),
          ]),
        ),
        communityRepositoryProvider
            .overrideWithValue(community ?? FakeCommunityRepository()),
        syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        appRestoreProvider.overrideWithValue(NoopAppRestore()),
      ],
      child: const CarlysApp(),
    );

Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(item, 240, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    seedCompletedFirstRun();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('question du jour, entrée nutrition et leçons par domaine',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    expect(find.text('QUESTION DU JOUR'), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
    // Les quatre domaines, en-têtes de section. Chaque libellé est unique et
    // la liste est PARESSEUSE : le viseur doit tolérer zéro correspondance
    // tant qu'on n'a pas défilé jusqu'à la section (`.first` planterait).
    for (final category in AcademyCategory.values) {
      await reveal(tester, find.text(category.label.toUpperCase()));
    }
  });

  testWidgets('une leçon se déplie : corps puis quiz, repliée par défaut',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    await reveal(tester, find.byType(LessonCard).first);
    final firstLesson = find.byType(LessonCard).first;
    // Repliée : pas de quiz dans l'arbre (retiré, pas masqué).
    expect(
      find.descendant(of: firstLesson, matching: find.byType(QuizCard)),
      findsNothing,
    );

    await tester.tap(firstLesson);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: firstLesson, matching: find.byType(QuizCard)),
      findsOneWidget,
    );
  });

  testWidgets('répondre au quiz révèle l’explication — juste ou faux',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    // La question du jour est en tête d'écran, prête à répondre.
    final quiz = find.byType(QuizCard).first;
    final quizCard = tester.widget<QuizCard>(quiz);
    final question = quizCard.question;

    // Réponse volontairement FAUSSE (ou la deuxième, si la bonne est la
    // première) : l'explication doit s'afficher quand même.
    final wrongIndex = question.answerIndex == 0 ? 1 : 0;
    await tester.tap(
      find
          .descendant(
            of: quiz,
            matching: find.text(question.choices[wrongIndex]),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: quiz, matching: find.text(question.explanation)),
      findsOneWidget,
    );
    // Et une fois répondu, on ne peut plus changer : un second tap sur un
    // autre choix ne modifie rien.
    await tester.tap(
      find
          .descendant(
            of: quiz,
            matching: find.text(question.choices[question.answerIndex]),
          )
          .first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: quiz, matching: find.text(question.explanation)),
      findsOneWidget,
    );
  });

  testWidgets('répondre rapporte la réponse aux défis culturels — une fois',
      (tester) async {
    final community = FakeCommunityRepository();
    await tester.pumpWidget(app(community: community));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    final quiz = find.byType(QuizCard).first;
    final question = tester.widget<QuizCard>(quiz).question;
    final wrongIndex = question.answerIndex == 0 ? 1 : 0;

    await tester.tap(
      find
          .descendant(
            of: quiz,
            matching: find.text(question.choices[wrongIndex]),
          )
          .first,
    );
    await tester.pumpAndSettle();

    // La réponse (fausse) est rapportée, avec le jour local.
    expect(community.quizReports, hasLength(1));
    final (lessonId, answeredOn, correct) = community.quizReports.single;
    expect(lessonId, isNotEmpty);
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(answeredOn), isTrue);
    expect(correct, isFalse);

    // Un second tap ne compte pas : la carte est verrouillée après réponse.
    await tester.tap(
      find
          .descendant(
            of: quiz,
            matching: find.text(question.choices[question.answerIndex]),
          )
          .first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(community.quizReports, hasLength(1));
  });

  testWidgets('une fiche d’anatomie mène aux exercices du muscle enseigné',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    // Ouvre la première fiche d'anatomie (les pectoraux).
    await reveal(tester, find.byType(LessonCard).first);
    await tester.tap(find.byType(LessonCard).first);
    await tester.pumpAndSettle();

    // L'essentiel à retenir est là, puis le pont vers la pratique.
    expect(find.text('À RETENIR'), findsOneWidget);
    final cta = find.text('Voir les exercices de ce muscle');
    await reveal(tester, cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    // La bibliothèque s'ouvre DÉJÀ filtrée sur le muscle de la fiche.
    expect(find.byType(SelectedGroupBar), findsOneWidget);
    expect(find.text('Pectoraux'), findsWidgets);
    expect(find.text('Développé couché'), findsOneWidget);
  });

  testWidgets('l’accueil pose la même question du jour', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Sur l'accueil, la carte « Question du jour » est plus bas dans la page.
    await reveal(tester, find.text('QUESTION DU JOUR'));
    expect(find.byType(QuizCard), findsOneWidget);
  });
}
