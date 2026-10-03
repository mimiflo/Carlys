import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que la page pose sous une réponse (« Écouter ») s'y trouve — et
/// jamais sous la question de la personne, ni sous une bulle vide.
void main() {
  Future<void> bulle(WidgetTester tester, CoachMessage message) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: CoachMessageBubble(
              message: message,
              maxWidth: 320,
              footer: const Text('ÉCOUTER'),
            ),
          ),
        ),
      );

  testWidgets('sous la réponse du coach', (tester) async {
    await bulle(
      tester,
      const CoachMessage(
        id: 'r1',
        role: CoachRole.assistant,
        content: 'Trois séries de dix.',
      ),
    );
    expect(find.text('ÉCOUTER'), findsOneWidget);
  });

  testWidgets('jamais sous la question de la personne', (tester) async {
    await bulle(
      tester,
      const CoachMessage(
        id: 'q1',
        role: CoachRole.user,
        content: 'Et demain ?',
      ),
    );
    expect(find.text('ÉCOUTER'), findsNothing);
  });

  testWidgets('rien à écouter dans une bulle vide', (tester) async {
    await bulle(
      tester,
      const CoachMessage(id: 'r2', role: CoachRole.assistant, content: '  '),
    );
    expect(find.text('ÉCOUTER'), findsNothing);
  });
}
