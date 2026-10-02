import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/data/dto/coach_dtos.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_live_bubble.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sa réflexion : ce que le coach a VRAIMENT fait avant de répondre.
void main() {
  const steps = ['Je regarde tes records', 'Je cherche des exercices'];

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('en direct, chaque étape se lit, la dernière en cours', (
    tester,
  ) async {
    await pump(
      tester,
      const CoachLiveBubble(text: '', steps: steps, stepRunning: true),
    );

    expect(find.text('Réflexion'), findsOneWidget);
    expect(find.text('Je regarde tes records'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Je regarde tes records, fait'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Je cherche des exercices, en cours'),
      findsOneWidget,
    );
    // Les étapes disent déjà qu'il travaille : pas de « Réfléchit… » en plus.
    expect(find.text('Réfléchit…'), findsNothing);
  });

  testWidgets('le texte commencé, les étapes sont faites, la réponse dessous', (
    tester,
  ) async {
    await pump(
      tester,
      const CoachLiveBubble(text: 'Ton record au squat : 80 kg.', steps: steps),
    );

    expect(
      find.bySemanticsLabel('Je cherche des exercices, fait'),
      findsOneWidget,
    );
    expect(find.text('Ton record au squat : 80 kg.'), findsOneWidget);
  });

  testWidgets('une étape lancée APRÈS du texte s’anime, elle aussi', (
    tester,
  ) async {
    await pump(
      tester,
      const CoachLiveBubble(
        text: 'Je regarde ça.',
        steps: steps,
        stepRunning: true,
      ),
    );

    expect(
      find.bySemanticsLabel('Je cherche des exercices, en cours'),
      findsOneWidget,
    );
  });

  testWidgets('archivée : repliée en une ligne, dépliée d’un appui', (
    tester,
  ) async {
    await pump(
      tester,
      const CoachMessageBubble(
        message: CoachMessage(
          id: 'a',
          role: CoachRole.assistant,
          content: 'Voici ta séance.',
          steps: steps,
        ),
        maxWidth: 320,
      ),
    );

    expect(find.text('Réflexion · 2 étapes'), findsOneWidget);
    expect(find.text('Je regarde tes records'), findsNothing);

    await tester.tap(find.text('Réflexion · 2 étapes'));
    await tester.pumpAndSettle();

    expect(find.text('Je regarde tes records'), findsOneWidget);
    expect(find.text('Voici ta séance.'), findsOneWidget);
  });

  testWidgets('sans étape, la réponse seule', (tester) async {
    await pump(
      tester,
      const CoachMessageBubble(
        message: CoachMessage(
          id: 'a',
          role: CoachRole.assistant,
          content: 'Avec plaisir !',
        ),
        maxWidth: 320,
      ),
    );

    expect(find.textContaining('Réflexion'), findsNothing);
  });

  test('les étapes se lisent du serveur ; absentes d’une copie ancienne', () {
    final json = {
      'id': 'a',
      'role': 'ASSISTANT',
      'content': 'Salut',
      'proposal': null,
      'programProposal': null,
      'createdAt': '2026-10-02T08:00:00.000Z',
    };
    expect(coachMessageFromJson(json).steps, isEmpty);
    expect(coachMessageFromJson({...json, 'steps': steps}).steps, steps);
  });
}
