import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/data/dto/coach_dtos.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
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

  Future<void> pump(WidgetTester tester, List<CoachMessage> messages) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: CoachThreadView(
            messages: messages,
            live: null,
            maxBubbleWidth: 300,
            onOpenProposal: (_) {},
          ),
        ),
      ),
    );
  }

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
