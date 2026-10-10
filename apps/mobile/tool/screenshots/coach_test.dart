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
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_page_states.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_state_view.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_training_frame.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/mentor/presentation/widgets/mentor_speak_button.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/training_goal_providers.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/presentation/providers/workout_template_providers.dart';
import 'package:carlys_mobile/features/workout_template/presentation/screens/templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/fake_exercises_repository.dart';
import '../../test/support/fake_training_profile_repository.dart';
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
    steps: const [
      'Je relis tes dernières séances',
      'Je cherche des exercices',
      'Je prépare ta séance',
    ],
    thinkingSeconds: 32,
    // Toute séance proposée est gardée dans « Mes modèles », catégorie Coach.
    createdWorkout: (templateId: 'p1', name: 'Haut du corps, format court'),
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

const List<CoachSuggestion> _suggestions = [
  CoachSuggestion(
    'Adapte « Push force » à 30 minutes',
    CoachSuggestionKind.adapt,
  ),
  CoachSuggestion(
    'Explique-moi le pourquoi de mes séances',
    CoachSuggestionKind.understand,
  ),
  CoachSuggestion(
    'Comment continuer sur Développé couché ?',
    CoachSuggestionKind.progress,
  ),
];

void main() {
  setUpAll(loadRealFonts);

  Future<void> pumpCoach(
    WidgetTester tester, {
    required List<CoachMessage> messages,
    bool isOffline = false,
    CoachLiveTurn? live,
    CoachGreeting? greeting,
    TrainingProfile? profile,
    TrainingGoal? goal,
    String? profileLabel,
    CoachRefusal? notice,
    String composerText = '',
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final controller = TextEditingController(text: composerText);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (profile != null)
            trainingProfileRepositoryProvider.overrideWithValue(
              FakeTrainingProfileRepository(initial: profile),
            ),
          exercisesRepositoryProvider.overrideWithValue(
            FakeExercisesRepository(const [])
              ..equipmentRefs = const [
                EquipmentRef(id: 'e1', slug: 'halteres', name: 'Haltères'),
                EquipmentRef(id: 'e2', slug: 'banc', name: 'Banc'),
              ],
          ),
          currentTrainingGoalProvider.overrideWithValue(goal),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: CoachScreen(
            frame: profile == null ? null : const CoachTrainingFrame(),
            // Comme la page : « Écouter » sous chaque réponse du coach.
            replyFooter: (reply) => MentorSpeakButton(
              speechKey: 'coach.${reply.id}',
              text: reply.content,
              size: 18,
              compact: true,
            ),
            messages: messages,
            // La règle de la page : les amorces s'effacent dès la première
            // question du jour.
            suggestions:
                live != null || coachWroteToday(messages, DateTime.now())
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
            profileLabel: profileLabel,
            onOpenProfile: () {},
            notice: notice,
          ),
        ),
      ),
    );
    await tester.pump();
    // La réflexion déroule ses étapes une à une, une seconde chacune.
    if (live != null) {
      for (var i = 0; i <= live.steps.length; i++) {
        await tester.pump(AppMotion.reflectionStep);
      }
    }
    if (profile != null) await tester.pumpAndSettle();
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

  testWidgets('coach — accueil, fil vide (maquette d’octobre 2026)', (
    tester,
  ) async {
    await pumpCoach(tester, messages: const [], profileLabel: 'Stratège');
    await capture(tester, 'coach-00-accueil');
  });

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

  // Sa réflexion : ce qu'il fait VRAIMENT, étape par étape, avant d'écrire.
  testWidgets('coach — le coach réfléchit', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      // La première étape faite, la seconde en cours, le chrono à 12 s.
      live: CoachLiveTurn(
        question: question,
        steps: const [
          'Je relis tes dernières séances',
          'Je regarde ta progression',
        ],
        done: const {'Je relis tes dernières séances'},
        // Une demi-seconde de marge : le chrono lit la vraie horloge.
        since: DateTime.now().subtract(const Duration(milliseconds: 12500)),
      ),
    );
    await capture(tester, 'coach-03-reflexion');
  });

  testWidgets('coach — il réfléchit, avant toute étape', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      // Rien lu encore : le chrono court déjà, jamais un « Réfléchit… » nu.
      live: CoachLiveTurn(
        question: question,
        since: DateTime.now().subtract(const Duration(milliseconds: 4500)),
      ),
    );
    await capture(tester, 'coach-10-reflexion-debut');
  });

  testWidgets('coach — la séance enregistrée', (tester) async {
    await pumpCoach(
      tester,
      messages: [
        ..._conversation,
        CoachMessage(
          id: 'm4',
          role: CoachRole.user,
          content: 'Ok crée-la.',
          createdAt: _today.add(const Duration(minutes: 2)),
        ),
        CoachMessage(
          id: 'm5',
          role: CoachRole.assistant,
          content:
              'C’est enregistré : « Haut du corps, format court » t’attend '
              'dans tes séances, prête à lancer.',
          steps: const ['J’enregistre ta séance'],
          createdWorkout: (
            templateId: 'modele-1',
            name: 'Haut du corps, format court',
          ),
          createdAt: _today.add(const Duration(minutes: 2)),
        ),
      ],
    );
    await capture(tester, 'coach-11-seance-enregistree');
  });

  // Le cadre : sans objectif ni matériel, il les demande d'emblée…
  testWidgets('coach — objectif et matériel à choisir', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      profile: const TrainingProfile(
        goal: null,
        experience: null,
        weeklySessionsTarget: null,
        sessionMinutesTarget: null,
        equipmentSlugs: [],
      ),
    );
    await capture(tester, 'coach-12-objectif-a-choisir');
  });

  // … puis, choisis, une ligne les rappelle.
  testWidgets('coach — objectif rappelé', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      goal: TrainingGoal.muscleGain,
      profile: const TrainingProfile(
        goal: TrainingGoal.muscleGain,
        experience: TrainingExperience.intermediate,
        weeklySessionsTarget: 3,
        sessionMinutesTarget: 45,
        equipmentSlugs: ['halteres', 'banc'],
      ),
    );
    await capture(tester, 'coach-13-objectif-rappel');
  });

  testWidgets('coach — sa réflexion, dépliée sous la réponse', (tester) async {
    await pumpCoach(tester, messages: _conversation);
    await tester.tap(find.text('Réflexion en 32 s · 3 étapes'));
    await tester.pumpAndSettle();
    await capture(tester, 'coach-09-reflexion-depliee');
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
        steps: ['Je relis tes dernières séances', 'Je regarde ta progression'],
        done: {'Je relis tes dernières séances', 'Je regarde ta progression'},
        thoughtFor: Duration(seconds: 14),
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

  testWidgets('coach — limite du jour, la question gardée', (tester) async {
    await pumpCoach(
      tester,
      messages: _conversation,
      notice: const CoachRefusal(
        CoachRefusalKind.limit,
        'Tu as atteint le nombre de messages du jour. Le coach revient '
        'demain.',
      ),
      composerText: 'Et pour demain, je fais quoi ?',
    );
    await capture(tester, 'coach-16-limite');
  });

  // Les états hors conversation, dans le cadre de la page.
  Future<void> pumpState(WidgetTester tester, Widget state) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: CoachShell(child: state),
      ),
    );
    await tester.pump();
  }

  testWidgets('coach — réservé à Premium', (tester) async {
    await pumpState(tester, const CoachPremiumState());
    await capture(tester, 'coach-17-premium');
  });

  testWidgets('coach — en pause', (tester) async {
    await pumpState(
      tester,
      CoachStateView(
        badge: AppIcons.coachPaused,
        title: 'Le coach est en pause',
        message: 'Il est momentanément indisponible. Réessaie plus tard.',
        actionLabel: 'Réessayer',
        actionIcon: AppIcons.retry,
        onAction: () {},
      ),
    );
    await capture(tester, 'coach-18-pause');
  });

  testWidgets('coach — ouverture', (tester) async {
    await pumpState(
      tester,
      const CoachStateView(
        title: 'Ouverture du coach',
        message: 'Un instant…',
        isLoading: true,
      ),
    );
    // L'anneau indéterminé part d'un point : on le laisse tourner un peu.
    await tester.pump(const Duration(milliseconds: 600));
    await capture(tester, 'coach-19-chargement');
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

  // Toute séance proposée par le coach est gardée : « Mes modèles », Coach.
  testWidgets('séances — la catégorie Coach', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    WorkoutTemplateInfo modele(
      String id,
      String nom,
      List<String> exercices, {
      bool coach = false,
      int minutes = 45,
    }) => WorkoutTemplateInfo(
      id: id,
      name: nom,
      exercisesCount: exercices.length,
      plannedSetsCount: exercices.length * 3,
      estimatedDurationMinutes: minutes,
      previewExerciseNames: exercices,
      updatedAt: _today,
      syncState: LocalSyncState.synced,
      fromCoach: coach,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutTemplatesProvider.overrideWith(
            (ref) => Stream.value([
              modele(
                'a',
                'Haut du corps, format court',
                [
                  'Développé couché',
                  'Tirage horizontal',
                  'Développé militaire',
                ],
                coach: true,
                minutes: 25,
              ),
              modele('b', 'Push A', ['Développé couché', 'Dips', 'Élévations']),
              modele(
                'c',
                'Jambes, quadriceps et fessiers',
                ['Squat', 'Fentes', 'Hip thrust'],
                coach: true,
                minutes: 40,
              ),
              modele('d', 'Pull B', ['Tractions', 'Rowing', 'Curl']),
            ]),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const TemplatesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'coach-14-mes-seances');
    await tester.tap(find.text('Coach').first);
    await tester.pumpAndSettle();
    await capture(tester, 'coach-15-mes-seances-coach');
  });
}
