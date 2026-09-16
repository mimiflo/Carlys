import 'dart:convert';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/data/answered_lessons_store.dart';
import 'package:carlys_mobile/features/academy/domain/academy_journey.dart';
import 'package:carlys_mobile/features/academy/presentation/screens/journey_screen.dart';
import 'package:carlys_mobile/features/academy/presentation/screens/journey_stage_screen.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/journey_entry_card.dart';
import 'package:carlys_mobile/features/academy/presentation/widgets/quiz_card.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_community_repository.dart';

/// Le Parcours à l'écran : six étapes, une reprise, une validation.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  Future<void> monterEcran(WidgetTester tester, Widget ecran) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Répondre rapporte la réponse aux défis culturels : sans ce
          // faux, le test tenterait un appel réseau.
          communityRepositoryProvider.overrideWithValue(
            FakeCommunityRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: ecran),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la vue d’ensemble montre les six étapes, rien de verrouillé', (
    tester,
  ) async {
    await monterEcran(tester, const JourneyScreen());

    // La liste est paresseuse : chaque étape se révèle en défilant, et
    // aucun verrou n'apparaît nulle part sur le chemin. Pas de `.first`
    // sur le finder : sur un itérable encore vide, il LÈVE au lieu de
    // laisser le défilement chercher — le nom d'une étape est unique ici.
    for (final stage in academyJourney) {
      await tester.scrollUntilVisible(find.text(stage.nom), 160);
      expect(find.text(stage.nom), findsOneWidget, reason: stage.nom);
      expect(find.byIcon(AppIcons.lock), findsNothing);
    }
  });

  testWidgets('une étape déroule ses leçons dans l’ordre du manifeste', (
    tester,
  ) async {
    await monterEcran(tester, const JourneyStageScreen(rang: 2));

    expect(find.text('Étape 2 · Nutrition'), findsOneWidget);
    // La première leçon du manifeste de l'étape est en tête de liste.
    expect(find.text('Le bilan calorique'), findsOneWidget);
  });

  testWidgets('un rang inconnu a son état vide, pas un plantage', (
    tester,
  ) async {
    await monterEcran(tester, const JourneyStageScreen(rang: 9));
    expect(find.text('Étape introuvable'), findsOneWidget);
  });

  testWidgets('répondre à la dernière leçon de l’étape la VALIDE, une fois', (
    tester,
  ) async {
    // L'étape 2 (Nutrition) entière sauf une leçon : répondre à la
    // dernière déclenche le bandeau de validation.
    final stage = academyJourney[1];
    SharedPreferences.setMockInitialValues({
      AnsweredLessonsStore.key: jsonEncode({
        for (final id in stage.lessonIds.skip(1)) id: 0,
      }),
    });

    await monterEcran(tester, const JourneyStageScreen(rang: 2));
    expect(find.textContaining('Étape validée'), findsNothing);

    // Ouvre la première leçon (la seule sans réponse) et répond.
    await tester.tap(find.text('Le bilan calorique'));
    await tester.pumpAndSettle();
    final quiz = find.byType(QuizCard).first;
    final question = tester.widget<QuizCard>(quiz).question;
    final choix = find
        .descendant(of: quiz, matching: find.text(question.choices.first))
        .first;
    await tester.scrollUntilVisible(choix, 200);
    await tester.pumpAndSettle();
    await tester.tap(choix);
    await tester.pumpAndSettle();

    final bandeau = find.textContaining('Étape validée');
    await tester.scrollUntilVisible(bandeau, -200);
    expect(bandeau, findsOneWidget);

    // Le bandeau se ferme, et ne revient pas.
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Étape validée'), findsNothing);
  });

  testWidgets('une réponse qui ne finit PAS l’étape ne valide rien', (
    tester,
  ) async {
    // Aucune leçon lue : répondre à la première ne franchit rien, et un
    // bandeau qui paraîtrait quand même dirait « validée » à une étape aux
    // quatre cinquièmes vide.
    await monterEcran(tester, const JourneyStageScreen(rang: 2));

    await tester.tap(find.text('Le bilan calorique'));
    await tester.pumpAndSettle();
    final quiz = find.byType(QuizCard).first;
    final question = tester.widget<QuizCard>(quiz).question;
    final choix = find
        .descendant(of: quiz, matching: find.text(question.choices.first))
        .first;
    await tester.scrollUntilVisible(choix, 200);
    await tester.pumpAndSettle();
    await tester.tap(choix);
    await tester.pumpAndSettle();

    expect(find.textContaining('Étape validée'), findsNothing);
  });

  group('la carte d’entrée', () {
    JourneyProgress avancement({int? courante, int faites = 0}) =>
        JourneyProgress(
          parEtape: [
            for (var i = 0; i < academyJourney.length; i++)
              StageProgress(
                abordees: i < faites ? 1 : 0,
                total: i < faites ? 1 : academyJourney[i].lessonIds.length,
              ),
          ],
          etapeCourante: courante,
          prochaineLecon: courante == null
              ? null
              : academyJourney[courante].lessonIds.first,
        );

    testWidgets('dit l’étape courante et propose de reprendre', (tester) async {
      var repris = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: JourneyEntryCard(
              progress: avancement(courante: 1, faites: 1),
              onOpen: () {},
              onResume: () => repris = true,
            ),
          ),
        ),
      );

      expect(find.text('Étape 2 · Nutrition'), findsOneWidget);
      await tester.tap(find.text('Reprendre'));
      expect(repris, isTrue);
    });

    testWidgets('avant la première leçon, elle dit « Commencer »', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: JourneyEntryCard(
              progress: avancement(courante: 0),
              onOpen: () {},
              onResume: () {},
            ),
          ),
        ),
      );

      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('un parcours terminé le dit, sans bouton de reprise', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: JourneyEntryCard(
              progress: avancement(courante: null, faites: 6),
              onOpen: () {},
              onResume: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Terminé'), findsOneWidget);
      expect(find.text('Reprendre'), findsNothing);
    });
  });
}
