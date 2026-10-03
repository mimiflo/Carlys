import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/coaching/presentation/providers/coach_frame_providers.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_page.dart';
import 'package:carlys_mobile/features/coaching/presentation/utils/coach_frame.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_coach_repository.dart';
import '../../support/fake_subscription_repository.dart';

/// L'objectif AVANT la réflexion : sans lui, la première question ouvre
/// l'écran de préparation, et ne part — le coach ne réfléchit — qu'au retour.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final thread = CoachConversationSummary(
    id: '11111111-1111-4111-8111-111111111111',
    messagesCount: 2,
    updatedAt: DateTime.utc(2026, 8, 9),
  );

  Future<void> monter(
    WidgetTester tester,
    FakeCoachRepository repository, {
    required List<String> manque,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const CoachPage()),
        GoRoute(
          path: AppRoutes.programSetup,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Préparation choisie'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachRepositoryProvider.overrideWithValue(repository),
          subscriptionRepositoryProvider.overrideWithValue(
            FakeSubscriptionRepository(coaching: true),
          ),
          coachSuggestionsProvider.overrideWithValue(const []),
          coachVoiceProvider.overrideWithValue((
            displayName: 'Léa',
            style: null,
          )),
          coachFrameMissingProvider.overrideWithValue(manque),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> envoyer(WidgetTester tester, String question) async {
    await tester.enterText(find.byType(TextField), question);
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();
  }

  testWidgets('pas d’objectif : il le DEMANDE d’abord, et répond au retour', (
    tester,
  ) async {
    final repository = FakeCoachRepository(threads: [thread]);
    await monter(tester, repository, manque: const ['ton objectif']);

    await envoyer(tester, 'Une séance jambes ?');
    // L'écran de préparation, et rien d'envoyé : il ne réfléchit pas encore.
    expect(find.text('Préparation choisie'), findsOneWidget);
    expect(repository.sent, isEmpty);

    await tester.tap(find.text('Préparation choisie'));
    await tester.pumpAndSettle();
    expect(repository.sent, ['Une séance jambes ?']);
  });

  testWidgets('deux appuis pendant que l’écran s’ouvre : une seule question', (
    tester,
  ) async {
    final repository = FakeCoachRepository(threads: [thread]);
    await monter(tester, repository, manque: const ['ton objectif']);

    await tester.enterText(find.byType(TextField), 'Une fois ?');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.tap(find.bySemanticsLabel('Envoyer'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Préparation choisie'));
    await tester.pumpAndSettle();

    expect(repository.sent, ['Une fois ?']);
  });

  testWidgets('une fois par visite : revenir sans choisir ne relance pas', (
    tester,
  ) async {
    final repository = FakeCoachRepository(threads: [thread]);
    await monter(tester, repository, manque: const ['ton objectif']);

    await envoyer(tester, 'Première ?');
    await tester.tap(find.text('Préparation choisie'));
    await tester.pumpAndSettle();
    await envoyer(tester, 'Seconde ?');

    expect(find.text('Préparation choisie'), findsNothing);
    expect(repository.sent, ['Première ?', 'Seconde ?']);
  });

  testWidgets('tout est choisi : la question part tout de suite', (
    tester,
  ) async {
    final repository = FakeCoachRepository(threads: [thread]);
    await monter(tester, repository, manque: const []);

    await envoyer(tester, 'Où j’en suis ?');
    expect(find.text('Préparation choisie'), findsNothing);
    expect(repository.sent, ['Où j’en suis ?']);
  });

  test('ce qui manque se dit dans l’ordre, en français', () {
    const vide = TrainingProfile(
      goal: null,
      experience: null,
      weeklySessionsTarget: null,
      sessionMinutesTarget: null,
      equipmentSlugs: [],
    );
    final manque = coachFrameMissing(vide, null);
    expect(coachFrameList(manque), 'ton objectif, ton niveau et ton matériel');
    expect(coachFrameMissing(vide, TrainingGoal.values.first), [
      'ton niveau',
      'ton matériel',
    ]);
  });
}
