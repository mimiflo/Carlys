// Capture de l'écran Coach IA — OUTIL, exécuté à la demande :
//   flutter test tool/screenshots/coach_test.dart --update-goldens
//
// L'écran est PRÉSENTATIONNEL : il reçoit ses données. Le jeu d'exemple vit
// donc ICI, dans un fichier de test, et jamais dans `lib/` — c'est la règle du
// dépôt : les mocks n'existent que dans les tests, isolés et remplaçables.
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test.dart' show loadRealFonts;

/// Conversation d'exemple : la question la plus fréquente qu'un pratiquant se
/// pose un soir de semaine, et la seule réponse qui l'aide — une séance.
const List<CoachMessage> _conversation = [
  CoachMessage(
    id: 'm1',
    role: CoachRole.assistant,
    content: 'Bonjour Clarisse ! Comment puis-je t’aider aujourd’hui ?',
  ),
  CoachMessage(
    id: 'm2',
    role: CoachRole.user,
    content: 'J’ai peu de temps aujourd’hui, que me conseilles-tu ?',
  ),
  CoachMessage(
    id: 'm3',
    role: CoachRole.assistant,
    content:
        'Tu as 25 minutes : je garde tes deux mouvements lourds, je retire '
        'les accessoires et je resserre les repos.',
    proposal: CoachSessionProposal(
      id: 'p1',
      name: 'Haut du corps, format court',
      estimatedMinutes: 25,
      exercises: [
        CoachProposedExercise(
          name: 'Développé couché',
          setCount: 4,
          detail: '6 reps · 60 kg',
        ),
        CoachProposedExercise(
          name: 'Tirage horizontal',
          setCount: 4,
          detail: '8 reps · 55 kg',
        ),
        CoachProposedExercise(
          name: 'Développé militaire',
          setCount: 3,
          detail: '8 reps · 32,5 kg',
        ),
      ],
    ),
  ),
];

const List<String> _suggestions = [
  'Ajuster ma séance',
  'Où j’en suis ?',
];

void main() {
  setUpAll(loadRealFonts);

  Future<void> pumpCoach(
    WidgetTester tester, {
    required List<CoachMessage> messages,
    List<String> suggestions = _suggestions,
    bool isOffline = false,
    bool isSending = false,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: CoachScreen(
          messages: messages,
          suggestions: suggestions,
          composerController: controller,
          onSend: (_) {},
          onOpenProposal: (_) {},
          isOffline: isOffline,
          isSending: isSending,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('coach — conversation avec séance proposée', (tester) async {
    await pumpCoach(tester, messages: _conversation);
    await capture(tester, 'coach-01-conversation');
  });

  testWidgets('coach — première ouverture', (tester) async {
    await pumpCoach(tester, messages: const []);
    await capture(tester, 'coach-02-vide');
  });

  testWidgets('coach — le coach rédige', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation.sublist(0, 2),
      isSending: true,
    );
    await capture(tester, 'coach-03-redaction');
  });

  testWidgets('coach — hors ligne', (tester) async {
    await pumpCoach(tester, messages: _conversation, isOffline: true);
    await capture(tester, 'coach-04-hors-ligne');
  });
}
