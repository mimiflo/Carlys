import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/domain_completed_banner.dart';
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
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(storedSession: true),
    ),
    workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
    exercisesRepositoryProvider.overrideWithValue(
      FakeExercisesRepository([
        summary('e1', 'Développé couché', group: 'pectoraux'),
        summary('e2', 'Écarté haltères', group: 'pectoraux'),
      ]),
    ),
    communityRepositoryProvider.overrideWithValue(
      community ?? FakeCommunityRepository(),
    ),
    syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
    appRestoreProvider.overrideWithValue(NoopAppRestore()),
  ],
  child: const CarlysApp(),
);

/// Le défilement VERTICAL de la page, et lui seul.
///
/// `find.byType(Scrollable).last` suffisait tant que l'écran n'en portait
/// qu'un. La barre de domaines en ajoute un horizontal : « le dernier »
/// tombait dessus, et chaque `reveal` tentait de faire défiler la page
/// latéralement. On désigne donc l'axe explicitement.
Finder get _pageScrollable => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable &&
      (widget.axisDirection == AxisDirection.down ||
          widget.axisDirection == AxisDirection.up),
);

Future<void> reveal(WidgetTester tester, Finder item) async {
  await tester.scrollUntilVisible(item, 240, scrollable: _pageScrollable.last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    seedCompletedFirstRun();
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('question du jour et leçons par domaine', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    expect(find.text('QUESTION DU JOUR'), findsOneWidget);
    // La CARTE d'entrée vers l'écran Nutrition a quitté l'Academy en
    // septembre 2026 : la nutrition a son propre onglet, et deux portes pour
    // un même écran valent moins qu'une seule, évidente. On vise son
    // sous-titre, pas le mot « Nutrition » : celui-ci reste légitimement à
    // l'écran, en pastille de domaine et en étiquette d'onglet.
    expect(
      find.text('Métabolisme, objectifs caloriques et macros.'),
      findsNothing,
    );
    // Les quatre domaines, en-têtes de section. Chaque libellé est unique et
    // la liste est PARESSEUSE : le viseur doit tolérer zéro correspondance
    // tant qu'on n'a pas défilé jusqu'à la section (`.first` planterait).
    for (final category in AcademyCategory.values) {
      await reveal(tester, find.text(category.label.toUpperCase()));
    }
  });

  testWidgets('une leçon se déplie : corps puis quiz, repliée par défaut', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    // Le finder passé à `reveal` vise UNE leçon nommée, et non
    // `find.byType(LessonCard).first`. Deux pièges de `scrollUntilVisible` à
    // la fois : `.first` sur un finder qui ne matche encore rien LÈVE
    // (`_FirstFinderMixin` fait `.first` sur un itérable vide), et le type
    // nu en matche plusieurs une fois la liste construite, ce qui lève
    // aussi (`.single`). Un titre unique traverse les deux.
    const premiere = 'Les protéines, brique du muscle';
    await reveal(tester, find.text(premiere));
    final firstLesson = find.ancestor(
      of: find.text(premiere),
      matching: find.byType(LessonCard),
    );
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

  testWidgets('répondre au quiz révèle l’explication — juste ou faux', (
    tester,
  ) async {
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

  testWidgets('répondre rapporte la réponse aux défis culturels — une fois', (
    tester,
  ) async {
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

  testWidgets('une fiche d’anatomie mène aux exercices du muscle enseigné', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    // Ouvre la fiche des pectoraux, désignée par son TITRE et non par sa
    // position : l'ordre des sections est un choix éditorial qui bouge
    // (la nutrition est passée en tête en septembre 2026), et un test qui
    // tape « la première carte » se casse à chaque réorganisation en
    // faisant croire à une régression de navigation.
    final fiche = find.text('Les pectoraux, un éventail');
    await reveal(tester, fiche);
    await tester.tap(fiche);
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
  testWidgets('la barre de domaines filtre, et « Tous » déroule tout', (
    tester,
  ) async {
    // CE QUE CE TEST PROTÈGE : à douze domaines, dérouler la totalité dans
    // une liste unique transforme l'Academy en couloir, il fallait traverser
    // onze domaines pour en atteindre un. La barre permet de viser ;
    // « Tous » garde la flânerie.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    // On vise une pastille déjà visible : ce qui est éprouvé ici est le
    // FILTRE, pas le défilement horizontal de la barre. « Musculation » est
    // aussi un libellé unique à l'écran, contrairement à « Nutrition » que
    // porte également l'onglet du bas.
    await tester.tap(find.widgetWithText(AppPill, 'Musculation'));
    await tester.pumpAndSettle();

    // ON N'ASSERTE QUE SUR CE QUI EST RÉELLEMENT CONSTRUIT. La liste est
    // paresseuse : un domaine situé plus bas n'est pas dans l'arbre, filtre
    // ou pas, et l'affirmer absent ne prouverait RIEN. La première version de
    // ce test tombait dans ce piège, et passait encore avec le filtre
    // débranché. Nutrition est le PREMIER domaine : sans filtre il est en
    // haut de page, donc bâti. Son absence ici a du sens.
    expect(find.text('Les protéines, brique du muscle'), findsNothing);
    expect(find.text('NUTRITION'), findsNothing);
    // Et la première leçon visible appartient au domaine visé.
    await reveal(tester, find.text('La surcharge progressive'));
    expect(find.text('La surcharge progressive'), findsOneWidget);
    // L'en-tête de section RESTE en vue filtrée depuis qu'il porte
    // l'avancement : il ne répète plus le nom que la pastille active dit
    // déjà, il ajoute « 0 / 4 » et sa jauge.
    expect(find.text('MUSCULATION'), findsOneWidget);
    expect(find.text('0 / 4'), findsOneWidget);

    // Retour à « Tous ». La barre de domaines vit DANS la liste : le
    // défilement précédent l'a sortie de l'arbre, il faut remonter avant de
    // pouvoir la viser.
    await tester.drag(_pageScrollable.last, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppPill, 'Tous'));
    await tester.pumpAndSettle();
    // La carte d'avancement et la question du jour occupent le haut : le
    // premier domaine est juste sous le pli, donc pas encore construit.
    await reveal(tester, find.text('NUTRITION'));
    expect(find.text('NUTRITION'), findsOneWidget);
    expect(find.text('Les protéines, brique du muscle'), findsOneWidget);
    // Et le dernier domaine reste atteignable en défilant.
    await reveal(tester, find.text('CALISTHENICS'));
  });

  testWidgets('l’Academy dit enfin où on en est, et dans quelle unité', (
    tester,
  ) async {
    // Elle n'affichait AUCUN chiffre d'avancement, et ses trois récompenses
    // de maîtrise ne paraissaient que sur les écrans de progression.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Academy');

    expect(find.text('OÙ TU EN ES'), findsOneWidget);
    expect(find.textContaining('leçons sur'), findsOneWidget);
    expect(find.text('Aucun domaine bouclé pour l’instant.'), findsOneWidget);
    // Un COMPTE, jamais un pourcentage : l'axe « Maîtrise » du profil
    // rapporte déjà ces mêmes leçons à une autre base, et deux nombres pour
    // un seul travail est exactement ce que la règle de non-concurrence
    // interdit.
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('la fête d’un domaine bouclé se ferme et ne revient pas', (
    tester,
  ) async {
    var ferme = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: DomainCompletedBanner(
            domaine: AcademyCategory.nutrition,
            onDismiss: () => ferme = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Domaine bouclé'), findsOneWidget);
    expect(find.text(AcademyCategory.nutrition.label), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(ferme, isTrue);
  });
}
