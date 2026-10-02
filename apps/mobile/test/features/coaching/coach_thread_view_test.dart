import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/data/dto/coach_dtos.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach_thread_state.dart';
import 'package:carlys_mobile/features/coaching/domain/services/coach_greeting.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_greeting_bubble.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_live_bubble.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_thread_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les dates dans la conversation : revenir le lendemain et comparer n'a de
/// sens que si l'on voit quel échange date de quel jour.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);
  final yesterday = today.subtract(const Duration(days: 1));
  final lastWeek = today.subtract(const Duration(days: 6));

  CoachMessage message(String id, DateTime? at) => CoachMessage(
    id: id,
    role: CoachRole.user,
    content: 'Message $id',
    createdAt: at,
  );

  Future<void> pump(
    WidgetTester tester,
    List<CoachMessage> messages, {
    CoachGreeting? greeting,
    CoachLiveTurn? live,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: CoachThreadView(
            messages: messages,
            live: live,
            maxBubbleWidth: 300,
            onOpenProposal: (_) {},
            onOpenProgram: (_) {},
            greeting: greeting,
          ),
        ),
      ),
    );
  }

  testWidgets('le bonjour arrive après un « Réfléchit… », à l’ouverture', (
    tester,
  ) async {
    await pump(
      tester,
      const [],
      // L'horloge du widget est la vraie : sous charge, le temps de monter
      // l'arbre dépassait l'attente et le bonjour arrivait déjà écrit. Une
      // ouverture un peu à venir garde l'attente, quelle que soit la machine.
      greeting: CoachGreeting(
        text: 'Bonjour Florian !',
        after: 0,
        at: DateTime.now().add(const Duration(seconds: 5)),
      ),
    );

    expect(find.byType(CoachLiveBubble), findsOneWidget);
    expect(find.text('Bonjour Florian !'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(CoachLiveBubble), findsNothing);
    expect(find.text('Bonjour Florian !'), findsOneWidget);
    // Un fil vide commence aujourd'hui : le bonjour a son jour.
    expect(find.text('Aujourd’hui'), findsOneWidget);
  });

  testWidgets('moins d’animations : le bonjour est là tout de suite', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pump(
      tester,
      const [],
      greeting: CoachGreeting(text: 'Bonjour !', after: 0, at: DateTime.now()),
    );
    await tester.pump();

    expect(find.text('Bonjour !'), findsOneWidget);
  });

  testWidgets('une réponse qui arrive ne fait pas rejouer l’attente du '
      'bonjour', (tester) async {
    // Le bonjour est arrivé il y a un moment ; une question part : le fil
    // s'allonge sous lui, et la liste reconstruit sa bulle à un autre rang.
    final greeting = CoachGreeting(
      text: 'Re-bonjour !',
      after: 1,
      at: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    await pump(tester, [message('a', today)], greeting: greeting);
    await pump(
      tester,
      [message('a', today)],
      greeting: greeting,
      live: const CoachLiveTurn(question: 'Et demain ?'),
    );
    await tester.pump();

    // Un seul « Réfléchit… » : celui de la vraie réponse.
    expect(find.byType(CoachLiveBubble), findsOneWidget);
    expect(find.text('Re-bonjour !'), findsOneWidget);
  });

  testWidgets('le bonjour se pose là où le fil en était à l’ouverture', (
    tester,
  ) async {
    await pump(
      tester,
      [message('hier', yesterday), message('après', today)],
      greeting: CoachGreeting(
        text: 'Re-bonjour !',
        after: 1,
        at: DateTime.now(),
      ),
    );
    await tester.pumpAndSettle();

    final hier = tester.getTopLeft(find.text('Message hier')).dy;
    final bonjour = tester.getTopLeft(find.text('Re-bonjour !')).dy;
    final apres = tester.getTopLeft(find.text('Message après')).dy;
    expect(hier, lessThan(bonjour));
    expect(bonjour, lessThan(apres));
    // « Aujourd’hui » au-dessus du bonjour, et pas une seconde fois sous lui.
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.byType(CoachGreetingBubble), findsOneWidget);
  });

  testWidgets('un séparateur par jour, au premier message de ce jour', (
    tester,
  ) async {
    await pump(tester, [
      message('a', lastWeek),
      message('b', lastWeek.add(const Duration(minutes: 5))),
      message('c', yesterday),
      message('d', today),
      message('e', today.add(const Duration(hours: 2))),
    ]);

    expect(find.text(formatSpokenDay(lastWeek, now)), findsOneWidget);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsOneWidget);
  });

  testWidgets('un message sans date n’invente pas de jour', (tester) async {
    await pump(tester, [message('a', null), message('b', null)]);

    expect(find.byType(CoachDaySeparator), findsNothing);
  });

  test('la date du serveur (UTC) se lit dans le message', () {
    final parsed = coachMessageFromJson({
      'id': 'm1',
      'role': 'USER',
      'content': 'Salut',
      'createdAt': '2026-09-29T21:30:00.000Z',
    });

    expect(parsed.createdAt, DateTime.utc(2026, 9, 29, 21, 30));
  });
}
