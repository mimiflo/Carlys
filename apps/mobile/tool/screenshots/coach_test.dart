// Capture de l'écran Coach IA — OUTIL, exécuté à la demande :
//   flutter test tool/screenshots/coach_test.dart --update-goldens
//
// L'écran est PRÉSENTATIONNEL : il reçoit ses données. Le jeu d'exemple vit
// donc ICI, dans un fichier de test, et jamais dans `lib/` — c'est la règle du
// dépôt : les mocks n'existent que dans les tests, isolés et remplaçables.
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach_thread_state.dart';
import 'package:carlys_mobile/features/coaching/domain/services/coach_greeting.dart';
import 'package:carlys_mobile/features/coaching/domain/services/coach_suggestions.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_screen.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test.dart' show loadRealFonts;

/// Aujourd'hui à 18 h, en heure locale : les séparateurs de jour se lisent
/// « Hier » et « Aujourd’hui », quel que soit le jour de la capture.
final DateTime _today = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 18);
}();

/// Conversation d'exemple : la question la plus fréquente qu'un pratiquant se
/// pose un soir de semaine, et la seule réponse qui l'aide — une séance. Elle
/// commence la veille, pour montrer les séparateurs de jour.
final List<CoachMessage> _conversation = [
  CoachMessage(
    id: 'm1',
    role: CoachRole.assistant,
    content: 'Bonjour Clarisse ! Comment puis-je t’aider aujourd’hui ?',
    createdAt: _today.subtract(const Duration(days: 1)),
  ),
  CoachMessage(
    id: 'm2',
    role: CoachRole.user,
    content: 'J’ai peu de temps aujourd’hui, que me conseilles-tu ?',
    createdAt: _today,
  ),
  CoachMessage(
    id: 'm3',
    createdAt: _today.add(const Duration(minutes: 1)),
    role: CoachRole.assistant,
    content:
        'Tu as 25 minutes : je garde tes deux mouvements lourds, je retire '
        'les accessoires et je resserre les repos.',
    proposal: const CoachSessionProposal(
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

const List<String> _suggestions = ['Ajuster ma séance', 'Où j’en suis ?'];

void main() {
  setUpAll(loadRealFonts);

  Future<void> pumpCoach(
    WidgetTester tester, {
    required List<CoachMessage> messages,
    bool isOffline = false,
    CoachLiveTurn? live,
    CoachGreeting? greeting,
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
          // La règle de la page : les amorces s'effacent dès la première
          // question du jour.
          suggestions: live != null || coachWroteToday(messages, DateTime.now())
              ? const []
              : _suggestions,
          composerController: controller,
          onSend: (_) {},
          onOpenProposal: (_) {},
          onOpenProgram: (_) {},
          onRetry: () {},
          // Comme dans l'appli : pendant une réponse, l'envoi devient « Arrêter ».
          onStop: () {},
          isOffline: isOffline,
          live: live,
          greeting: greeting,
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

  // Le bonjour de l'ouverture, tel que la page l'écrit : après son court
  // « Réfléchit… », d'où l'attente avant la capture.
  CoachGreeting greet({required bool returning, required int after}) =>
      CoachGreeting(
        text: coachGreeting(
          displayName: 'Clarisse',
          style: null,
          returning: returning,
          now: _today,
        ),
        after: after,
        at: DateTime.now(),
      );

  testWidgets('coach — première ouverture', (tester) async {
    await pumpCoach(
      tester,
      messages: const [],
      greeting: greet(returning: false, after: 0),
    );
    // L'arrivée, puis le fondu vers le texte.
    await tester.pump(AppMotion.reveal);
    await tester.pump(AppMotion.normal);
    await tester.pump(AppMotion.normal);
    await capture(tester, 'coach-02-vide');
  });

  testWidgets('coach — retour : il dit bonjour sous le fil', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      greeting: greet(returning: true, after: _conversation.length),
    );
    // L'arrivée, puis le fondu vers le texte.
    await tester.pump(AppMotion.reveal);
    await tester.pump(AppMotion.normal);
    await tester.pump(AppMotion.normal);
    await capture(tester, 'coach-08-bonjour');
  });

  // Le tour en direct s'écrit SOUS l'échange précédent : un fil plein,
  // comme à l'usage, plutôt qu'une question seule sur un écran vide.
  const question = 'Et demain, je fais quoi pour récupérer ?';

  testWidgets('coach — le coach réfléchit', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      live: const CoachLiveTurn(question: question),
    );
    await capture(tester, 'coach-03-reflexion');
  });

  // Le coach sollicité (ADR 0013) : la file se dit, au lieu d'un silence.
  testWidgets('coach — en attente, d’autres passent avant', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      live: const CoachLiveTurn(question: question, ahead: 2),
    );
    await capture(tester, 'coach-07-en-attente');
  });

  testWidgets('coach — la réponse s’écrit en direct', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      live: const CoachLiveTurn(
        question: question,
        text:
            'Demain, place à la récupération active : 20 minutes de vélo '
            'tranquille, puis des étirements pour les pectoraux et',
      ),
    );
    await capture(tester, 'coach-05-direct');
  });

  testWidgets('coach — hors ligne', (tester) async {
    await pumpCoach(tester, messages: _conversation, isOffline: true);
    await capture(tester, 'coach-04-hors-ligne');
  });

  // Un programme proposé : le coach choisit les réglages, Carlys construit.
  testWidgets('coach — programme proposé', (tester) async {
    await pumpCoach(
      tester,
      messages: [
        ..._conversation,
        CoachMessage(
          id: 'm4',
          role: CoachRole.user,
          content: 'Tu peux me faire un programme pour gagner en force ?',
          createdAt: _today.add(const Duration(minutes: 5)),
        ),
        CoachMessage(
          id: 'm5',
          role: CoachRole.assistant,
          content:
              'Trois séances de 45 minutes : assez pour progresser sur tes '
              'mouvements lourds, et tenable avec tes soirées.',
          createdAt: _today.add(const Duration(minutes: 6)),
          programProposal: const CoachProgramProposal(
            id: 'pp1',
            goal: TrainingGoal.strength,
            weeklySessions: 3,
            sessionMinutes: 45,
          ),
        ),
      ],
    );
    await capture(tester, 'coach-06-programme');
  });
}
