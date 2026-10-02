import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/data/dto/coach_dtos.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach_thread_state.dart';
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

  testWidgets(
    'en direct : trois points tant qu’elle se fait, la coche une fois finie',
    (tester) async {
      await pump(
        tester,
        CoachLiveBubble(
          text: '',
          steps: steps,
          done: const {'Je regarde tes records'},
          since: DateTime.now().subtract(const Duration(seconds: 12)),
        ),
      );

      // Le chrono court, à la seconde.
      expect(find.text('Réflexion · 12 s'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Je regarde tes records, fait'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Je cherche des exercices, en cours'),
        findsOneWidget,
      );
      expect(find.text('Je réfléchis à ta réponse'), findsNothing);
      expect(find.text('Réfléchit…'), findsNothing);
    },
  );

  testWidgets(
    'ses étapes faites, il réfléchit encore : une ligne qui s’anime',
    (tester) async {
      await pump(
        tester,
        CoachLiveBubble(
          text: '',
          steps: steps,
          done: steps.toSet(),
          since: DateTime.now(),
        ),
      );

      expect(
        find.bySemanticsLabel('Je réfléchis à ta réponse, en cours'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'le premier mot écrit : « Réflexion en 14 s », la réponse dessous',
    (tester) async {
      await pump(
        tester,
        CoachLiveBubble(
          text: 'Ton record au squat : 80 kg.',
          steps: steps,
          done: steps.toSet(),
          since: DateTime.now().subtract(const Duration(seconds: 20)),
          thoughtFor: const Duration(seconds: 14),
        ),
      );

      expect(find.text('Réflexion en 14 s'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Je cherche des exercices, fait'),
        findsOneWidget,
      );
      expect(find.text('Je réfléchis à ta réponse'), findsNothing);
      expect(find.text('Ton record au squat : 80 kg.'), findsOneWidget);
    },
  );

  testWidgets('une étape lancée APRÈS du texte s’anime jusqu’à sa fin', (
    tester,
  ) async {
    await pump(
      tester,
      const CoachLiveBubble(
        text: 'Je regarde ça.',
        steps: steps,
        done: {'Je regarde tes records'},
        thoughtFor: Duration(seconds: 3),
      ),
    );

    expect(
      find.bySemanticsLabel('Je cherche des exercices, en cours'),
      findsOneWidget,
    );
  });

  testWidgets(
    'archivée : « Réflexion en 32 s · 2 étapes », dépliée d’un appui',
    (tester) async {
      await pump(
        tester,
        const CoachMessageBubble(
          message: CoachMessage(
            id: 'a',
            role: CoachRole.assistant,
            content: 'Voici ta séance.',
            steps: steps,
            thinkingSeconds: 32,
          ),
          maxWidth: 320,
        ),
      );

      expect(find.text('Réflexion en 32 s · 2 étapes'), findsOneWidget);
      expect(find.text('Je regarde tes records'), findsNothing);

      await tester.tap(find.text('Réflexion en 32 s · 2 étapes'));
      await tester.pumpAndSettle();

      expect(find.text('Je regarde tes records'), findsOneWidget);
      expect(find.text('Voici ta séance.'), findsOneWidget);
    },
  );

  testWidgets(
    'archivée sans durée (avant qu’on la mesure) : ses étapes seules',
    (tester) async {
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
    },
  );

  testWidgets(
    'avant toute étape : déjà la réflexion et son chrono, pas « Réfléchit… »',
    (tester) async {
      // Constaté le 2 octobre 2026 : « Réfléchit… » nu pendant 16 s, puis
      // d'un coup « Réflexion en 16 s » et l'étape déjà cochée.
      await pump(
        tester,
        CoachLiveBubble(
          text: '',
          since: DateTime.now().subtract(const Duration(seconds: 5)),
        ),
      );

      expect(find.text('Réflexion · 5 s'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Je réfléchis à ta réponse, en cours'),
        findsOneWidget,
      );
      expect(find.text('Réfléchit…'), findsNothing);
    },
  );

  testWidgets('sans étape, le premier mot écrit : « Réflexion en 6 s »', (
    tester,
  ) async {
    await pump(
      tester,
      CoachLiveBubble(
        text: 'Avec plaisir !',
        since: DateTime.now().subtract(const Duration(seconds: 9)),
        thoughtFor: const Duration(seconds: 6),
      ),
    );

    expect(find.text('Réflexion en 6 s'), findsOneWidget);
    expect(find.text('Je réfléchis à ta réponse'), findsNothing);
  });

  testWidgets('archivée sans étape : sa durée seule, rien à déplier', (
    tester,
  ) async {
    await pump(
      tester,
      const CoachMessageBubble(
        message: CoachMessage(
          id: 'a',
          role: CoachRole.assistant,
          content: 'Avec plaisir !',
          thinkingSeconds: 6,
        ),
        maxWidth: 320,
      ),
    );

    expect(find.text('Réflexion en 6 s'), findsOneWidget);
    expect(find.byIcon(AppIcons.expand), findsNothing);
  });

  testWidgets('ni étape ni durée (copie ancienne) : la réponse seule', (
    tester,
  ) async {
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

  test('le chrono se recale sur le temps que le serveur a mesuré', () {
    final sent = DateTime.now().subtract(const Duration(seconds: 3));
    final live = CoachLiveTurn(question: 'Par où je commence ?', since: sent)
        .step((
          label: 'Je regarde tes records',
          done: false,
          elapsed: const Duration(seconds: 1),
        ));

    // Le coach réfléchit depuis 1 s, pas depuis l'envoi (3 s).
    final since = live.since!;
    expect(DateTime.now().difference(since).inMilliseconds, lessThan(1500));
    expect(live.steps, ['Je regarde tes records']);

    final done = live.step((
      label: 'Je regarde tes records',
      done: true,
      elapsed: null,
    ));
    expect(done.done, {'Je regarde tes records'});
    // Sans temps mesuré, le chrono garde son départ.
    expect(done.since, since);
  });

  test('la séance enregistrée se lit du serveur ; absente, aucune', () {
    final json = {
      'id': 'a',
      'role': 'ASSISTANT',
      'content': 'C’est enregistré.',
      'createdAt': '2026-10-02T08:00:00.000Z',
    };
    expect(coachMessageFromJson(json).createdWorkout, isNull);
    expect(
      coachMessageFromJson({
        ...json,
        'createdWorkout': {'templateId': 'modele-1', 'name': 'Jambes'},
      }).createdWorkout,
      (templateId: 'modele-1', name: 'Jambes'),
    );
    // Une forme inattendue ne fait pas tomber le fil.
    expect(
      coachMessageFromJson({
        ...json,
        'createdWorkout': {'templateId': 3},
      }).createdWorkout,
      isNull,
    );
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
    expect(coachMessageFromJson(json).thinkingSeconds, isNull);
    expect(
      coachMessageFromJson({...json, 'thinkingSeconds': 32}).thinkingSeconds,
      32,
    );
  });
}
