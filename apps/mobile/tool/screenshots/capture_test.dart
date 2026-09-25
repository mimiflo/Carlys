// Galerie d'écrans de l'app — OUTIL DE CAPTURE, exécuté à la demande :
//   flutter test tool/screenshots --update-goldens
// Volontairement HORS de test/ : la CI ne compare jamais ces rendus
// (fragiles entre versions de moteur) ; les PNG générés sont ignorés par git.
//
// Ce fichier EST un harnais de test (exécuté via `flutter test`), simplement
// rangé hors de test/ — l'avertissement visible_for_testing est donc infondé :
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/core/utilities/debouncer.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/presentation/screens/academy_screen.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/register_screen.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/screens/carlys_profiles_screen.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/carlys_profile_content.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_screen.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:carlys_mobile/features/community/presentation/screens/friend_challenge_screen.dart';
import 'package:carlys_mobile/features/dashboard/presentation/screens/home_screen.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/title_summary.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_workout_card.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/presentation/screens/exercise_detail_screen.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/muscle_group_card.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/muscle_group_grid.dart';
import 'package:carlys_mobile/features/notifications/data/repositories/device_token_repository_impl.dart';
import 'package:carlys_mobile/features/notifications/data/services/firebase_push_messenger.dart';
import 'package:carlys_mobile/features/notifications/domain/entities/push_destination.dart';
import 'package:carlys_mobile/features/notifications/domain/services/push_messenger.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/meal_editor_controller.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/water_controllers.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:carlys_mobile/features/onboarding/domain/first_run_step.dart';
import 'package:carlys_mobile/features/onboarding/presentation/controllers/splash_gate.dart';
import 'package:carlys_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:carlys_mobile/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:carlys_mobile/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/athlete_photo.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/brand_signature.dart';
import 'package:carlys_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:carlys_mobile/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_plan_card.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/screens/exercise_progression_screen.dart';
import 'package:carlys_mobile/features/progress/presentation/screens/progress_screen.dart';
import 'package:carlys_mobile/features/progress/presentation/screens/timeline_screen.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_weight_section.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/manifesto_tile.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/progression_entry_card.dart';
import 'package:carlys_mobile/features/progression/presentation/widgets/seal_engraving.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:carlys_mobile/features/training/presentation/screens/training_hub_screen.dart';
import 'package:carlys_mobile/features/workout_history/presentation/screens/workout_history_screen.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/program_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/presentation/screens/program_calendar_screen.dart';
import 'package:carlys_mobile/features/workout_program/presentation/screens/program_detail_screen.dart';
import 'package:carlys_mobile/features/workout_program/presentation/screens/programs_screen.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_calendar_day_row.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_calendar_day_sheet.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/screens/active_workout_screen.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:carlys_mobile/shared/widgets/summit_illustration.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test/support/fake_auth_repository.dart';
import '../../test/support/fake_coach_repository.dart';
import '../../test/support/fake_exercises_repository.dart';
import '../../test/support/fake_nutrition_repository.dart';
import '../../test/support/fake_progress_repository.dart';
import '../../test/support/fake_push_messenger.dart';
import '../../test/support/fake_subscription_repository.dart';
import '../../test/support/fake_water_store.dart';
import '../../test/support/fake_workout_repository.dart';
import '../../test/support/first_run_prefs.dart';
import '../../test/support/in_memory_community_repository.dart';
import '../../test/support/in_memory_device_token_repository.dart';
import '../../test/support/in_memory_program_repository.dart';
import '../../test/support/in_memory_workout_template_repository.dart';
import '../../test/support/sample_meal_photo.dart';
import '../../test/support/sample_meals.dart';

/// Minuit de la journée en cours.
///
/// Les repas de la galerie s'y ancrent : « il y a N heures » bascule la
/// veille quand la capture tourne après minuit, et le total du jour change
/// d'une exécution à l'autre.
///
/// **Trois repas ne s'y ancraient pas**, malgré ce commentaire : ils
/// portaient `DateTime.now().subtract(...)`. Or la tuile REND l'heure
/// (`formatClock`), à la minute : deux régénérations à quinze
/// minutes d'écart donnaient deux images différentes, et la galerie ne
/// pouvait plus servir à prouver qu'un changement n'avait rien changé.
///
/// La règle complète des décors tient donc en deux temps : un JOUR se date
/// relativement à maintenant — sans quoi il vieillit —, et une HEURE se pose
/// en dur dans ce jour — sans quoi elle bouge à chaque exécution.
DateTime startOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Future<void> loadRealFonts() async {
  // Polices du bundle (MaterialIcons…).
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (data) async => json.decode(data) as List<dynamic>,
  );
  for (final entry in manifest.whereType<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    // LIMITE CONNUE : `FontLoader` n'expose aucun poids, et le harnais ne sait
    // donc pas choisir la graisse — c'est la PREMIÈRE fonte chargée qui sert à
    // tous les poids, les autres étant simulées. Les captures sous-rendent donc
    // le gras : mesuré, « TON PARCOURS. » en 24/w700 fait 192 px ici contre
    // ~211 sur un vrai appareil. On charge le 400 en tête, le plus proche de la
    // moyenne de l'interface — sans quoi une fonte fine déclarée en premier
    // amaigrirait toute la galerie.
    final fonts =
        (entry['fonts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList()
          ..sort((a, b) {
            int gap(Map<String, dynamic> f) =>
                ((f['weight'] as int?) ?? 400) - 400;
            return gap(a).abs().compareTo(gap(b).abs());
          });
    for (final font in fonts) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }

  // Roboto depuis le cache du SDK : rendu de texte réaliste (la police de
  // test « blocs » fausse largeurs et lisibilité des captures).
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final fontsDir = Directory(
      '$flutterRoot/bin/cache/artifacts/material_fonts',
    );
    // « FlutterTest » est la police par défaut du harnais (glyphes en blocs) :
    // la remplacer aussi rend les styles sans famille explicite lisibles.
    for (final family in const ['Roboto', 'FlutterTest']) {
      final loader = FontLoader(family);
      for (final file in fontsDir.listSync().whereType<File>()) {
        if (file.path.endsWith('.ttf') && file.path.contains('Roboto-')) {
          loader.addFont(
            file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        }
      }
      await loader.load();
    }
  }

  await _loadEmojiFont();
}

/// Police EMOJI du système, pour que la galerie ne mente pas.
///
/// L'application déclare trois familles emoji en repli (`AppTypography`), et
/// l'appareil fournit la sienne. Le harnais, lui, ne charge que les polices
/// du bundle : un message de la communauté qui finit par un emoji sortait
/// donc en tofu sur les captures, ce qui se lit comme un bug de
/// l'application alors que le rendu est juste sur un vrai téléphone.
///
/// Faute de police trouvée, on le DIT plutôt que de laisser croire à un
/// défaut : les captures montreront des tofus et l'opérateur saura pourquoi.
Future<void> _loadEmojiFont() async {
  const candidates = [
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    '/usr/share/fonts/noto/NotoColorEmoji.ttf',
    '/System/Library/Fonts/Apple Color Emoji.ttc',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    // Les trois familles déclarées en repli pointent vers le MÊME fichier :
    // le moteur prend la première qui répond, les autres sont ignorées.
    for (final family in AppTypography.emojiFallback) {
      final loader = FontLoader(family)
        ..addFont(
          file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
    return;
  }

  // ignore: avoid_print
  print(
    'Aucune police emoji sur cette machine : les captures afficheront des '
    'tofus là où un appareil rendrait un emoji.',
  );
}

FakeExercisesRepository catalogOf() => FakeExercisesRepository([
  summary('id-1', 'Développé couché', group: 'pectoraux'),
  summary('id-2', 'Squat', group: 'quadriceps'),
  summary('id-3', 'Tractions', group: 'dos'),
  summary('id-4', 'Soulevé de terre', group: 'lombaires'),
  summary('id-5', 'Pompes', group: 'pectoraux'),
], pageSize: 10);

/// La bibliothèque GARNIE des captures par groupe : un jeu réaliste pour
/// chacun des groupes visités. Les vignettes, elles, viennent du serveur
/// depuis le retrait du mode démo — la galerie montre donc les cartes sans
/// photo, ce qui EST l'état d'une bibliothèque hors connexion.
FakeExercisesRepository furnishedCatalogOf() => FakeExercisesRepository([
  summary('dos-1', 'Tractions lestées', group: 'dos'),
  summary('dos-2', 'Rowing barre', group: 'dos'),
  summary('dos-3', 'Tirage horizontal', group: 'dos'),
  summary('tri-1', 'Dips', group: 'triceps'),
  summary('tri-2', 'Barre au front', group: 'triceps'),
  summary('epa-1', 'Développé militaire', group: 'epaules'),
  summary('epa-2', 'Élévations latérales', group: 'epaules'),
  summary('abd-1', 'Planche', group: 'abdominaux'),
  summary('abd-2', 'Crunch', group: 'abdominaux'),
], pageSize: 20);

WorkoutWithSets activeWorkoutOf() {
  // Départ RELATIF : une date fixe vieillit, et le chrono de la galerie
  // affichait « 54:37:39 » — une séance de deux jours et demi.
  final startedAt = DateTime.now().toUtc().subtract(
    const Duration(minutes: 47),
  );
  WorkoutSetEntry set(int position, String name, int reps, double weight) =>
      WorkoutSetEntry(
        id: 'set-$position',
        exerciseName: name,
        position: position,
        kind: position == 0 ? SetKind.warmup : SetKind.normal,
        reps: reps,
        weightKg: weight,
        restSeconds: 90,
        completedAt: startedAt.add(Duration(minutes: 5 + position * 3)),
        syncState: position < 2
            ? LocalSyncState.synced
            : LocalSyncState.pending,
      );
  return WorkoutWithSets(
    session: WorkoutInfo(
      id: 'session-1',
      name: 'Push A',
      status: WorkoutStatus.inProgress,
      startedAt: startedAt,
      syncState: LocalSyncState.synced,
    ),
    sets: [
      set(0, 'Développé couché', 12, 40),
      set(1, 'Développé couché', 10, 60),
      set(2, 'Développé couché', 8, 70),
    ],
  );
}

/// Cinq séances récentes, datées RELATIVEMENT à aujourd'hui.
///
/// Elles l'étaient en août 2026 en dur, et la galerie l'a payé : au fil des
/// semaines, l'accueil s'est mis à annoncer « 43 jours de repos », une
/// semaine de constance vide et un volume à zéro — la capture phare du
/// produit montrait quelqu'un qui a arrêté. Une date figée dans un décor
/// vieillit ; un décalage, non.
///
/// Le calage sert l'écran : trois jours d'affilée (hier, avant-hier et le
/// jour d'avant) donnent une SÉRIE EN COURS, la journée d'aujourd'hui reste
/// libre pour que la tuile « Séance du jour » garde son appel à l'action, et
/// deux séances plus anciennes nourrissent l'historique.
List<WorkoutHistoryEntry> historyOf() {
  final midi = startOfToday().add(const Duration(hours: 9));
  WorkoutHistoryEntry entry(int recul, String name, int sets, double volume) =>
      WorkoutHistoryEntry(
        session: WorkoutInfo(
          id: 'h-$recul',
          name: name,
          status: WorkoutStatus.completed,
          startedAt: midi.subtract(Duration(days: recul)),
          endedAt: midi
              .subtract(Duration(days: recul))
              .add(const Duration(minutes: 52)),
          durationSeconds: 3120,
          syncState: LocalSyncState.synced,
        ),
        setsCount: sets,
        totalVolumeKg: volume,
      );
  return [
    entry(1, 'Push A', 14, 2140),
    entry(2, 'Legs', 12, 3260),
    entry(3, 'Pull A', 15, 1980),
    entry(5, 'Push B', 13, 2050),
    entry(7, 'Full body', 10, 1720),
  ];
}

/// Le compte du profil : une ancienneté, un profil Carlys, un objectif —
/// de quoi remplir chaque ligne de la carte d'identité.
final AuthUser profileUser = AuthUser(
  id: fakeUser.id,
  email: fakeUser.email,
  displayName: fakeUser.displayName,
  emailVerified: true,
  locale: fakeUser.locale,
  timezone: fakeUser.timezone,
  carlysProfile: CarlysProfile.challenger,
  trainingGoal: TrainingGoal.muscleGain,
  createdAt: DateTime.utc(2024, 3, 12, 9),
);

FakeProgressRepository progressOf() => FakeProgressRepository(
  // La galerie fixe sa semaine : « hier et avant-hier » peut tomber de part
  // et d'autre d'un lundi, et la tuile bascule alors de la DURÉE à
  // l'ASSIDUITÉ. C'est le comportement juste de l'application, mais une
  // vitrine qui change de tuile selon le jour où on la photographie n'est
  // pas une vitrine.
  overviewFor: (period) => overviewOf(period, points: pointsMemeSemaine()),
  records: [
    // Quatre reculs DISTINCTS : les records s'affichent en âge, et quatre
    // dates identiques se lisent comme une donnée fabriquée. Tous au-delà de
    // trois jours, pour que la maxime de l'accueil reste celle de la série
    // en cours plutôt que celle d'un record frais.
    recordOf(
      'Développé couché',
      PersonalRecordType.maxWeight,
      80,
      joursAvant: 3,
    ),
    recordOf('Développé couché', PersonalRecordType.maxReps, 12, joursAvant: 6),
    recordOf(
      'Développé couché',
      PersonalRecordType.maxSetVolume,
      700,
      joursAvant: 11,
    ),
    recordOf('Squat', PersonalRecordType.maxWeight, 120, joursAvant: 18),
  ],
  bodyMetrics: [
    for (final (index, value) in [
      86.0,
      85.2,
      84.6,
      84.9,
      83.8,
      83.1,
      82.5,
    ].indexed)
      BodyMetricEntry(
        id: 'w-$index',
        kind: BodyMetricKind.weightKg,
        value: value,
        // La dernière pesée date d'HIER, les autres remontent de six jours
        // en six jours. Figée au 25 juin, la série faisait dire « IL Y A
        // 2 MOIS » à la carte qui s'intitule « Dernière mesure ».
        measuredAt: startOfToday().toUtc().subtract(
          Duration(days: (6 - index) * 6 + 1),
        ),
      ),
  ],
);

/// Deux mois d'histoire : la vitrine de la FRISE.
///
/// Des six types, cinq sont représentés — séances, records, pesées, leçons,
/// récompense — parce que c'est le mélange qui fait la frise. Une liste de
/// séances seules ne serait qu'un historique.
List<ProgressEvent> timelineSampleOf() {
  ProgressEvent event(
    ProgressEventKind kind,
    int joursAvant,
    Map<String, dynamic> payload,
  ) => ProgressEvent(
    id: '${kind.apiValue}-$joursAvant',
    kind: kind,
    // Ancrée sur AUJOURD'HUI : les `joursAvant` gardent leur calage voulu
    // (un événement du jour, un groupe récent, deux plus anciens qui font
    // apparaître le second en-tête de mois) sans dater la capture.
    occurredAt: startOfToday()
        .toUtc()
        .add(const Duration(hours: 18))
        .subtract(Duration(days: joursAvant)),
    payload: payload,
  );

  return [
    event(ProgressEventKind.session, 0, {
      'name': 'Push A',
      'setsCount': 16,
      'volumeKg': 5400,
    }),
    event(ProgressEventKind.record, 0, {
      'exerciseName': 'Développé couché',
      'recordType': 'MAX_WEIGHT',
      'value': 85,
    }),
    event(ProgressEventKind.lesson, 1, {'lessons': 4}),
    event(ProgressEventKind.session, 2, {
      'name': 'Pull B',
      'setsCount': 14,
      'volumeKg': 4900,
    }),
    event(ProgressEventKind.measure, 3, {
      'metricType': 'WEIGHT_KG',
      'value': 78.4,
    }),
    event(ProgressEventKind.reward, 5, {'key': 'constance-4'}),
    event(ProgressEventKind.session, 5, {
      'name': 'Jambes',
      'setsCount': 18,
      'volumeKg': 7200,
    }),
    event(ProgressEventKind.record, 12, {
      'exerciseName': 'Squat',
      'recordType': 'MAX_SET_VOLUME',
      'value': 1080,
    }),
    event(ProgressEventKind.session, 26, {
      'name': 'Push A',
      'setsCount': 15,
      'volumeKg': 5100,
    }),
    event(ProgressEventKind.measure, 31, {
      'metricType': 'WEIGHT_KG',
      'value': 79.6,
    }),
  ];
}

/// Une course suivie sur six semaines : la vitrine de la courbe CARDIO.
///
/// Sans charge et sans volume, exprès — c'est le cas que la courbe de kilos
/// rendait comme « pas encore de courbe ».
ExerciseProgressionEntity cardioProgressionOf() => ExerciseProgressionEntity(
  exerciseId: 'course',
  exerciseName: 'Course à pied',
  records: const [],
  points: [
    for (final (index, (metres, secondes)) in const [
      (5000, 1980),
      (5600, 2100),
      (6200, 2220),
      (6000, 2040),
      (7100, 2400),
      (8000, 2580),
    ].indexed)
      ExerciseProgressionPoint(
        sessionId: 'c-$index',
        // Six séances espacées de six jours, la dernière HIER. Figée au
        // 3 août, la courbe « suivie sur six semaines » listait des séances
        // vieilles d'un mois : elle décrédibilisait ce qu'elle démontre.
        date: startOfToday()
            .toUtc()
            .subtract(Duration(days: (5 - index) * 6 + 1))
            .add(const Duration(hours: 7)),
        volumeKg: 0,
        distanceMeters: metres,
        durationSeconds: secondes,
      ),
  ],
);

/// Conversation d'exemple de la galerie : une question, une réponse, et la
/// séance qui en découle — c'est l'enchaînement que l'écran doit montrer.
FakeCoachRepository coachOf() {
  const proposal = CoachSessionProposal(
    id: 'p1',
    name: 'Haut du corps, format court',
    estimatedMinutes: 28,
    exercises: [
      CoachProposedExercise(
        name: 'Développé couché',
        setCount: 3,
        detail: '8 reps · 70 kg',
      ),
      CoachProposedExercise(name: 'Tractions', setCount: 3, detail: '6 reps'),
      CoachProposedExercise(
        name: 'Développé militaire',
        setCount: 3,
        detail: '10 reps · 35 kg',
      ),
    ],
  );

  return FakeCoachRepository(
    threads: [
      CoachConversationSummary(
        id: 'thread-1',
        title: 'Séance courte',
        messagesCount: 4,
        updatedAt: DateTime.utc(2026, 8, 9),
      ),
    ],
    messages: const [
      CoachMessage(
        id: 'm1',
        role: CoachRole.user,
        content: 'J’ai seulement 30 minutes aujourd’hui.',
      ),
      CoachMessage(
        id: 'm2',
        role: CoachRole.assistant,
        content:
            'On garde les deux mouvements principaux et on resserre les '
            'repos. Les charges ne bougent pas : c’est le volume qui tombe, '
            'pas l’intensité.',
        proposal: proposal,
      ),
    ],
  );
}

FakeNutritionRepository nutritionOf({bool complete = true}) => complete
    ? FakeNutritionRepository(
        weightKg: 82.5,
        sex: BiologicalSex.male,
        birthDate: DateTime.utc(1996, 3, 12),
        heightCm: 180,
        activityLevel: ActivityLevel.moderate,
        goal: NutritionGoal.gainMuscle,
      )
    : FakeNutritionRepository(weightKg: 82.5);

void main() {
  setUpAll(loadRealFonts);

  setUp(() {
    // Galerie d'une app déjà installée : le parcours de première ouverture
    // est terminé, sinon toutes les captures repartiraient du tunnel.
    seedCompletedFirstRun();
  });

  // Les scènes 3D bouclent en continu : pumps BORNÉS uniquement, calés
  // sur le pic de systole du battement (~80 ms) pour de belles captures.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 80));
  }

  /// Remonte la Communauté en haut de page SANS glisser : un glissé qui
  /// dépasse le haut arme « tirer pour rafraîchir », et la capture montrait
  /// l'anneau de chargement sous l'en-tête.
  Future<void> backToTop(WidgetTester tester) async {
    final page = find
        .descendant(
          of: find.byType(CommunityScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(page).position.jumpTo(0);
    await settle(tester);
  }

  /// Attente supplémentaire pour les scènes qui se DESSINENT : la gravure
  /// d'une récompense dure près d'une seconde, et `settle` en photographierait
  /// le milieu — un sceau à moitié tracé, qui n'existe qu'un instant.
  Future<void> settleEngraving(WidgetTester tester) async {
    await settle(tester);
    await tester.pump(EngravedSeal.engraveDuration);
    await tester.pump();
  }

  /// Un historique d'entraînement RÉEL pour la galerie : dix semaines
  /// consécutives à trois séances, le rythme d'une personne qui s'y tient.
  ///
  /// Sans lui, la galerie montrerait un compte vide — cinq axes « en
  /// attente » et zéro point, ce qui ne dit rien du système.
  List<WorkoutHistoryEntry> trainedHistory() {
    final start = DateTime.now().subtract(const Duration(days: 70));
    return [
      for (var week = 0; week < 10; week++)
        for (final day in [0, 2, 4])
          WorkoutHistoryEntry(
            session: WorkoutInfo(
              id: 'seance-$week-$day',
              startedAt: start.add(Duration(days: week * 7 + day)),
              status: WorkoutStatus.completed,
              syncState: LocalSyncState.synced,
            ),
            setsCount: 18,
            // Volume croissant : l'axe « Performance » compare les quatre
            // dernières semaines aux quatre précédentes.
            totalVolumeKg: 5200 + week * 240,
          ),
    ];
  }

  /// Laisse passer l'ÉCRAN DE DÉMARRAGE, qui tient l'affiche un temps
  /// minimum au lancement (voir `splashHold`).
  ///
  /// Sans cette attente, chaque capture photographierait le logo : la
  /// galerie n'a pas de session « déjà lancée », elle démarre l'application
  /// à neuf à chaque cadre.
  Future<void> passSplash(WidgetTester tester) async {
    await settle(tester);
    await tester.pump(splashHold);
    await settle(tester);
    await settle(tester);
  }

  /// Décode les images du bundle AVANT la capture.
  ///
  /// Le harnais de test fait tourner un temps FICTIF : le décodage d'une image,
  /// lui, est du vrai travail asynchrone, et ne s'achève jamais tant qu'on
  /// n'ouvre pas une fenêtre de temps réel. Sans ça, les écrans à photographie
  /// se capturent vides — et la capture ment.
  /// Les détourages des groupes musculaires : sans préchargement, le harnais
  /// capture la grille avant que les images ne soient décodées.
  Future<void> precacheMuscleImages(WidgetTester tester) async {
    final context = tester.element(find.byType(MaterialApp));
    for (final slug in <String?>[null, ...MuscleGroupCard.illustrated]) {
      final asset = MuscleGroupCard.assetFor(slug);
      if (asset == null) continue;
      await tester.runAsync(() => precacheImage(AssetImage(asset), context));
    }
    await settle(tester);
  }

  Future<void> precacheBrandImages(WidgetTester tester) async {
    final context = tester.element(find.byType(MaterialApp));
    for (final asset in const [BrandSignature.markAsset, AthletePhoto.asset]) {
      await tester.runAsync(() => precacheImage(AssetImage(asset), context));
    }
    await settle(tester);
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    bool authenticated = true,
    FakeExercisesRepository? exercises,
    FakeWorkoutRepository? workouts,
    FakeNutritionRepository? nutrition,
    FakeCoachRepository? coach,
    bool premium = false,

    /// Le compte connecté. Celui des tests par défaut, sauf pour le profil,
    /// qui a besoin d'une histoire (ancienneté, profil Carlys, objectif).
    AuthUser user = fakeUser,

    /// Ce que le « serveur » compte sur la vie entière — `null`, il se tait.
    LifetimeStats? lifetime,

    /// Arrête le temps PENDANT l'écran de démarrage, pour le photographier.
    bool holdOnSplash = false,

    /// Le messager des notifications, quand la scène en reçoit une.
    PushMessenger? messenger,

    /// Ce que rend la connexion Apple ou Google, quand la scène la fait
    /// échouer — une erreur du SDK ou du serveur, comme en production.
    Object? socialError,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.development,
              apiBaseUrl: 'http://localhost:3000',
            ),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedSession: authenticated, user: user)
              ..socialError = socialError,
          ),
          exercisesRepositoryProvider.overrideWithValue(
            exercises ?? catalogOf(),
          ),
          workoutRepositoryProvider.overrideWithValue(
            workouts ?? FakeWorkoutRepository(),
          ),
          progressRepositoryProvider.overrideWithValue(
            progressOf()..lifetime = lifetime,
          ),
          nutritionRepositoryProvider.overrideWithValue(
            nutrition ?? nutritionOf(),
          ),
          subscriptionRepositoryProvider.overrideWithValue(
            FakeSubscriptionRepository(isPremium: premium),
          ),
          coachRepositoryProvider.overrideWithValue(
            coach ?? FakeCoachRepository(),
          ),
          // Communauté en mémoire : sans doublure, le dépôt Dio réel
          // lancerait des requêtes (bloquées) dont les minuteurs de timeout
          // survivraient au test — et l'accueil perdrait sa carte « X
          // t'encourage », qui fait partie de la galerie.
          communityRepositoryProvider.overrideWithValue(
            InMemoryCommunityRepository(),
          ),
          programRepositoryProvider.overrideWithValue(
            InMemoryProgramRepository(),
          ),
          // L'accueil compte les modèles enregistrés : sans dépôt local, le
          // compte partirait au réseau et laisserait un minuteur en vol.
          workoutTemplateRepositoryProvider.overrideWithValue(
            InMemoryWorkoutTemplateRepository(
              workouts ?? FakeWorkoutRepository(),
            ),
          ),
          // Même raison que la communauté ci-dessus : sans doublure, l'écran
          // Profil demande ses préférences de notification au dépôt Dio réel,
          // et le minuteur de timeout survit au test.
          deviceTokenRepositoryProvider.overrideWithValue(
            InMemoryDeviceTokenRepository(),
          ),
          // Sans cette doublure, l'accueil ouvre un vrai flux Drift pour la
          // jauge d'eau, et sa fermeture au démontage laisse un minuteur en
          // vol — toute la galerie échouait sur « A Timer is still pending ».
          waterStoreProvider.overrideWithValue(
            FakeWaterStore(milliliters: 1250),
          ),
          // Les puces se calculent depuis les modèles de séance, qui vivent
          // dans Drift : la galerie n'ouvre pas de base locale, elle fige donc
          // le résultat que la règle donnerait pour ce jeu d'exemple.
          coachSuggestionsProvider.overrideWithValue(const [
            'Adapte « Push A » à 30 minutes',
            'Comment continuer sur Développé couché ?',
          ]),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
          if (messenger != null)
            pushMessengerProvider.overrideWithValue(messenger),
          // Base EN MÉMOIRE : sans cet écrasement, le harnais ouvrait la vraie
          // base de l'appareil — donc `path_provider`, absent des tests. Rien
          // n'échouait bruyamment, l'ouverture restait simplement en attente.
          appDatabaseProvider.overrideWith((ref) {
            final database = AppDatabase(NativeDatabase.memory());
            ref.onDispose(database.close);
            return database;
          }),
        ],
        child: const CarlysApp(),
      ),
    );
    if (holdOnSplash) {
      // Aux trois quarts de la scène : le sceau est posé, le fil de lumière
      // est engagé — l'instant qui montre le mieux l'écran.
      await settle(tester);
      await tester.pump(splashHold * 0.15);
      return;
    }
    await passSplash(tester);
  }

  /// Prend la capture — après avoir vérifié qu'on est bien sur le bon écran.
  ///
  /// `shows` n'est pas décoratif : sans lui, une navigation ratée produit un
  /// PNG parfaitement lisible… d'un autre écran, et personne ne le voit. C'est
  /// arrivé à `05-seance-active`, qui montrait la Progression.
  WidgetController.hitTestWarningShouldBeFatal = true;

  Future<void> capture(
    WidgetTester tester,
    String name, {
    required Finder shows,
  }) async {
    expect(shows, findsWidgets, reason: 'Mauvais écran pour « $name »');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  Future<void> goTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text(label),
      ),
    );
    await settle(tester);
  }

  // Depuis la réorganisation en CINQ onglets, les anciens onglets — exercices,
  // coach, nutrition, profil — se joignent en deux gestes : l'onglet porteur,
  // puis la carte du hub (ou l'avatar de l'accueil pour le profil).

  Future<void> openExercises(WidgetTester tester) async {
    await goTab(tester, 'Training');
    await tester.tap(find.text('Exercices'));
    await settle(tester);
  }

  Future<void> openCoach(WidgetTester tester) async {
    await goTab(tester, 'Training');
    await tester.tap(find.text('Coach IA'));
    await settle(tester);
  }

  /// Nutrition est un ONGLET depuis la réorganisation de la barre : le
  /// harnais la cherchait encore comme une carte du hub Academy, et
  /// « Nutrition » y désignait alors DEUX widgets (l'onglet et la carte) —
  /// un `tap` ambigu, donc trois captures impossibles à régénérer.
  Future<void> openNutrition(WidgetTester tester) => goTab(tester, 'Nutrition');

  /// L'avatar se repère par l'étiquette de son `Semantics`, côté widget :
  /// aucun `SemanticsHandle` n'est posé, l'arbre de sémantique n'existe pas.
  Future<void> openProfile(WidgetTester tester) async {
    await goTab(tester, 'Accueil');
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith('Profil'),
      ),
    );
    await settle(tester);
  }

  /// Les réglages : le profil, puis le rouage de son en-tête.
  Future<void> openProfileSettings(WidgetTester tester) async {
    await openProfile(tester);
    await tester.tap(find.byTooltip('Réglages'));
    await settle(tester);
  }

  testWidgets('chargement', (tester) async {
    // L'écran de démarrage se photographie EN COURS : c'est un passage, pas
    // une destination, et `pumpApp` le franchit par défaut.
    seedFirstRunStep(FirstRunStep.welcome);
    // Le décodage du sceau consomme lui aussi du temps fictif : viser tôt
    // dans la scène, sinon la capture tombe pendant la transition de sortie.
    await pumpApp(tester, authenticated: false, holdOnSplash: true);
    await precacheBrandImages(tester);
    await capture(tester, '00a-chargement', shows: find.byType(SplashScreen));
  });

  testWidgets('progression', (tester) async {
    await pumpApp(tester);
    await goTab(tester, 'Progrès');
    // La carte de titre vit sous le pli, et son libellé est mis en
    // capitales par `AppSectionLabel` : on vise le widget, pas son texte.
    await tester.scrollUntilVisible(find.byType(ProgressionEntryCard), 200);
    await settle(tester);
    await tester.tap(find.byType(ProgressionEntryCard));
    await settleEngraving(tester);
    await capture(tester, '37-progression', shows: find.text('Progression'));
  });

  testWidgets('accueil — la progression en place', (tester) async {
    // La carte de progression vit sous le pli de l'accueil : la galerie la
    // photographie là où elle se lit, pas en haut d'un écran qu'elle
    // n'occupe pas.
    await pumpApp(
      tester,
      workouts: FakeWorkoutRepository()..history = trainedHistory(),
    );
    await tester.scrollUntilVisible(find.byType(TitleSummary), 200);
    await settleEngraving(tester);
    await capture(
      tester,
      '02b-accueil-progression',
      shows: find.byType(TitleSummary),
    );
  });

  testWidgets('progrès — récompenses et records', (tester) async {
    await pumpApp(
      tester,
      workouts: FakeWorkoutRepository()..history = trainedHistory(),
    );
    await goTab(tester, 'Progrès');
    await tester.scrollUntilVisible(find.byType(ProgressionEntryCard), 200);
    await settleEngraving(tester);
    await capture(
      tester,
      '06b-progres-recompenses',
      shows: find.byType(ProgressScreen),
    );
  });

  testWidgets('progression nourrie', (tester) async {
    // Le même écran, pour quelqu'un qui s'entraîne depuis dix semaines :
    // titre gagné, écrin plus riche, récompenses au journal.
    await pumpApp(
      tester,
      workouts: FakeWorkoutRepository()..history = trainedHistory(),
    );
    await goTab(tester, 'Progrès');
    await tester.scrollUntilVisible(find.byType(ProgressionEntryCard), 200);
    await settle(tester);
    await tester.tap(find.byType(ProgressionEntryCard));
    await settleEngraving(tester);
    await capture(
      tester,
      '37b-progression-nourrie',
      shows: find.text('Progression'),
    );
  });

  testWidgets('progression — les cinq axes', (tester) async {
    // Le bas du profil : la carte des cinq axes et l'entrée du manifeste.
    // Sans cette vue, la galerie ne montrerait jamais la moitié de l'écran.
    await pumpApp(
      tester,
      workouts: FakeWorkoutRepository()..history = trainedHistory(),
    );
    await goTab(tester, 'Progrès');
    await tester.scrollUntilVisible(find.byType(ProgressionEntryCard), 200);
    await settle(tester);
    await tester.tap(find.byType(ProgressionEntryCard));
    await settleEngraving(tester);
    await tester.scrollUntilVisible(
      find.byType(ManifestoTile),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await capture(
      tester,
      '37c-progression-axes',
      shows: find.byType(ManifestoTile),
    );
  });

  testWidgets('progression — la courbe cardio d’un exercice', (tester) async {
    // L'écran par exercice, monté SEUL : il a son propre Scaffold et sa
    // propre barre, et l'atteindre par la navigation demanderait un record
    // porteur d'identifiant d'exercice que la vitrine n'a pas.
    final progress = progressOf()
      ..exerciseProgressions['course'] = cardioProgressionOf();

    // La surface et le bandeau de débogage viennent de `pumpApp` pour tous
    // les autres écrans : montés à la main, il faut les poser ici, sinon la
    // capture sort en paysage avec le ruban rouge dans le coin.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [progressRepositoryProvider.overrideWithValue(progress)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const ExerciseProgressionScreen(exerciseId: 'course'),
        ),
      ),
    );
    await settle(tester);
    // La courbe SE DESSINE en 600 ms, et `settle` n'en pompe que 430 : sans
    // cette attente, la capture montre un tracé coupé net à mi-chemin.
    await tester.pump(AppMotion.deliberate);
    await tester.pump();
    await capture(
      tester,
      '39-progression-cardio',
      shows: find.text('DISTANCE PAR SÉANCE'),
    );
  });

  testWidgets('progression — la frise', (tester) async {
    final progress = FakeProgressRepository()
      ..timelineEvents.addAll(timelineSampleOf());

    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [progressRepositoryProvider.overrideWithValue(progress)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const TimelineScreen(),
        ),
      ),
    );
    await settle(tester);
    await capture(
      tester,
      '40-progression-frise',
      shows: find.text('Ton histoire'),
    );
  });

  testWidgets('manifeste', (tester) async {
    await pumpApp(tester);
    await goTab(tester, 'Progrès');
    await tester.scrollUntilVisible(find.byType(ProgressionEntryCard), 200);
    await settle(tester);
    await tester.tap(find.byType(ProgressionEntryCard));
    await settle(tester);
    // La page de progression a sa PROPRE liste : viser explicitement la
    // dernière, sinon le défilement s'applique à celle de l'onglet Progrès
    // restée dessous, et la cible n'est jamais construite.
    await tester.scrollUntilVisible(
      find.text('Pourquoi essayer compte plus que réussir.'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(find.text('Pourquoi essayer compte plus que réussir.'));
    await settle(tester);
    await capture(tester, '38-manifeste', shows: find.text('Manifeste Carlys'));
  });

  testWidgets('bienvenue', (tester) async {
    // Parcours de première ouverture NON franchi : la page de marque est la
    // toute première chose que voit un nouvel arrivant.
    seedFirstRunStep(FirstRunStep.welcome);
    await pumpApp(tester, authenticated: false);
    await precacheBrandImages(tester);
    await capture(tester, '00-bienvenue', shows: find.byType(WelcomeScreen));
  });

  testWidgets('connexion', (tester) async {
    await pumpApp(tester, authenticated: false);
    // Le sceau de la signature est un asset : sans préchargement, la
    // capture montrerait son emplacement vide — sur téléphone, l'écran
    // de démarrage l'a déjà décodé.
    await precacheBrandImages(tester);
    await capture(tester, '01-connexion', shows: find.byType(LoginScreen));
  });

  testWidgets('connexion : échec Google et son code', (tester) async {
    // La popup d'échec telle que la voit un testeur de la bêta : la cause
    // en clair, puis le code et la référence de requête à recopier, sur
    // l'écran de connexion qui reste derrière. Une erreur SERVEUR, parce
    // que c'est la seule qui porte à la fois un code et une référence.
    await pumpApp(
      tester,
      authenticated: false,
      socialError: const ServerException(
        'Une erreur interne est survenue.',
        statusCode: 500,
        requestId: '1a2b3c4d-9e8f-4a5b-8c7d-0123456789ab',
      ),
    );
    await precacheBrandImages(tester);
    await tester.tap(find.bySemanticsLabel('Continuer avec Google'));
    // Assez pour que la carte finisse d'entrer, bien moins que les dix
    // secondes au bout desquelles elle repart.
    await settle(tester);
    await settle(tester);
    await capture(
      tester,
      '01c-connexion-echec-google',
      shows: find.text('Code\u00A0: http-500 · réf.\u00A01a2b3c4d'),
    );
  });

  testWidgets('inscription', (tester) async {
    // On y arrive comme un utilisateur : par le lien du bas de l'écran de
    // connexion. Capturer l'écran en le poussant directement masquerait une
    // rupture de navigation entre les deux.
    await pumpApp(tester, authenticated: false);
    await tester.tap(find.text('Créer un compte'));
    await settle(tester);
    await precacheBrandImages(tester);
    await capture(
      tester,
      '01b-inscription',
      shows: find.byType(RegisterScreen),
    );
  });

  testWidgets('accueil', (tester) async {
    // Un historique est nécessaire : sans lui, la série de constance
    // s'afficherait vide et la capture ne montrerait pas la fonctionnalité.
    // Et un journal entamé : la tuile Nutrition montre un VRAI consommé.
    await pumpApp(
      tester,
      workouts: FakeWorkoutRepository()..history = historyOf(),
      nutrition: nutritionOf()
        ..meals.addAll([
          // Les macros sont renseignées : sans elles, la tuile PROTÉINES
          // affichait « 0 / 128 g » sur la capture phare, et un journal sans
          // protéines n'existe pas dans la vraie vie.
          MealEntry(
            id: 'capture-repas-1',
            name: 'Skyr, granola',
            kcal: 380,
            proteinG: 28,
            carbsG: 44,
            fatG: 9,
            eatenAt: startOfToday().add(const Duration(hours: 8)),
          ),
          MealEntry(
            id: 'capture-repas-2',
            name: 'Poulet, riz',
            kcal: 274,
            proteinG: 31,
            carbsG: 26,
            fatG: 5,
            eatenAt: startOfToday().add(const Duration(hours: 12)),
          ),
        ]),
    );
    await capture(tester, '02-accueil', shows: find.byType(HomeScreen));
  });

  testWidgets('journal alimentaire', (tester) async {
    final nutrition = nutritionOf()
      ..meals.addAll([
        MealEntry(
          id: 'capture-repas-1',
          name: 'Skyr, granola, myrtilles',
          kcal: 380,
          quantity: 1,
          quantityUnit: MealQuantityUnit.portion,
          proteinG: 28,
          // Petit-déjeuner : une heure FIXE dans la journée en cours.
          eatenAt: startOfToday().add(const Duration(hours: 8, minutes: 15)),
        ),
        MealEntry(
          id: 'capture-repas-2',
          name: 'Poulet, riz, brocoli',
          kcal: 274,
          quantity: 320,
          quantityUnit: MealQuantityUnit.gram,
          proteinG: 46,
          // Déjeuner : heure FIXE, pour que deux captures coïncident.
          eatenAt: startOfToday().add(const Duration(hours: 13, minutes: 20)),
        ),
      ]);
    await pumpApp(tester, nutrition: nutrition);
    await openNutrition(tester);
    await tester.scrollUntilVisible(
      find.text('Journal'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await capture(tester, '30-nutrition-journal', shows: find.text('Journal'));
  });

  // L'écran « Ajouter / Modifier ce repas » (maquette du 25 septembre
  // 2026), ouvert comme on l'ouvre : depuis le journal. Il remplace la
  // feuille de correction de l'ancienne scène 31.
  //
  // LA PHOTO du repas composé est un DESSIN d'assiette vue de dessus
  // (`test/support/sample_meal_photo.dart`) : l'application n'embarque
  // aucune photo de plat, et l'image d'asset la plus proche (l'athlète de
  // la bienvenue) aurait montré autre chose qu'un repas. Le « serveur » la
  // rend par la même route que la vraie (GET authentifié du dépôt).
  Future<void> openMealFromJournal(WidgetTester tester, String label) async {
    await openNutrition(tester);
    await tester.scrollUntilVisible(
      find.text(label),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(find.text(label));
    await settle(tester);
    // La photo du plat se DÉCODE hors de l'horloge simulée, comme les
    // images d'asset des autres scènes : sans cela, la vignette resterait
    // vide sur la capture.
    final thumbnail = find.byType(AppThumbnail);
    final photo = thumbnail.evaluate().isEmpty
        ? null
        : tester.widget<AppThumbnail>(thumbnail).image;
    if (photo != null) {
      final context = tester.element(thumbnail);
      await tester.runAsync(() => precacheImage(photo, context));
      await settle(tester);
    }
  }

  /// Le déjeuner de la maquette, composé de trois aliments : 320 g, à une
  /// heure FIXE de la journée en cours, pour que deux captures coïncident ;
  /// avec sa photo, et une base d'aliments où chercher.
  FakeNutritionRepository composedWorld() {
    final lunch = composedLunch(
      eatenAt: startOfToday().add(const Duration(hours: 12, minutes: 30)),
    );
    return nutritionOf()
      ..foods.addEntries(
        searchableFoods.map((food) => MapEntry(food.code, food)),
      )
      ..meals.add(lunch)
      ..photos[lunch.id] = sampleMealPhotoJpeg();
  }

  testWidgets('repas composé — haut de l’écran', (tester) async {
    await pumpApp(tester, nutrition: composedWorld());
    await openMealFromJournal(tester, 'Poulet, riz, brocoli');
    await capture(
      tester,
      '31-repas-modifier-compose',
      shows: find.text('Modifier ce repas'),
    );
  });

  testWidgets('repas composé — bas de l’écran', (tester) async {
    await pumpApp(tester, nutrition: composedWorld());
    await openMealFromJournal(tester, 'Poulet, riz, brocoli');
    await tester.ensureVisible(find.text('Supprimer ce repas'));
    await settle(tester);
    await capture(
      tester,
      '31b-repas-modifier-compose-bas',
      shows: find.text('Aliments composant le repas'.toUpperCase()),
    );
  });

  testWidgets('recherche d’un aliment, depuis le repas composé', (
    tester,
  ) async {
    await pumpApp(tester, nutrition: composedWorld());
    await openMealFromJournal(tester, 'Poulet, riz, brocoli');
    await tester.ensureVisible(find.text('Ajouter un aliment'));
    await settle(tester);
    await tester.tap(find.text('Ajouter un aliment'));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AppSearchField),
        matching: find.byType(TextField),
      ),
      'riz',
    );
    // L'anti-rebond de la recherche, puis la réponse.
    await tester.pump(Debouncer.search);
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await capture(
      tester,
      '31d-repas-recherche-aliment',
      shows: find.textContaining('Ciqual (version 2020-07-07)'),
    );
  });

  // La feuille du bouton appareil photo, sur le repas composé qui A une
  // photo : ses trois choix, « Retirer la photo » compris. Puis la MÊME
  // feuille sur 320 points en texte doublé : chaque choix passe à la ligne
  // au lieu de se couper (« Choisir dans la gal… »).
  Future<void> openPhotoSheet(WidgetTester tester) async {
    await pumpApp(tester, nutrition: composedWorld());
    await openMealFromJournal(tester, 'Poulet, riz, brocoli');
    await tester.tap(find.byTooltip('Changer la photo'));
    await settle(tester);
  }

  testWidgets('la feuille de la photo du plat', (tester) async {
    await openPhotoSheet(tester);
    await capture(
      tester,
      '31e-repas-photo-feuille',
      shows: find.text('Retirer la photo'),
    );
  });

  testWidgets('la feuille de la photo du plat, 320 points, texte doublé', (
    tester,
  ) async {
    await openPhotoSheet(tester);
    tester.view.physicalSize = const Size(960, 1920);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await settle(tester);
    await capture(
      tester,
      '31f-repas-photo-feuille-grand-texte',
      shows: find.text('Choisir dans la galerie'),
    );
  });

  testWidgets('nouveau repas, en cours de saisie', (tester) async {
    await pumpApp(tester, nutrition: nutritionOf());
    await openNutrition(tester);
    await tester.scrollUntilVisible(
      find.text('Ajouter un repas'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(find.text('Ajouter un repas'));
    await settle(tester);

    // Une heure FIXE plutôt que « maintenant » : la pastille l'affiche, et
    // l'image ne doit pas changer d'une exécution à l'autre.
    final screen = tester.widget<MealEditorScreen>(
      find.byType(MealEditorScreen),
    );
    ProviderScope.containerOf(tester.element(find.byType(MealEditorScreen)))
        .read(
          mealEditorProvider((mealId: screen.mealId, day: screen.day)).notifier,
        )
        .setEatenAt(startOfToday().add(const Duration(hours: 8, minutes: 15)));
    // Un formulaire à moitié rempli, comme au milieu d'une vraie saisie :
    // un écran vide ne montrerait ni les tuiles saisies ni l'unité.
    Finder field(String label) => find.descendant(
      of: find.widgetWithText(AppTextField, label),
      matching: find.byType(TextField),
    );
    Finder tile(String label) => find.descendant(
      of: find.widgetWithText(AppNutrientTile, label),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('Nom du repas'), 'Skyr, granola, myrtilles');
    await tester.enterText(tile('Calories'), '380');
    await tester.enterText(tile('Protéines'), '28');
    await tester.enterText(tile('Glucides'), '44');
    await settle(tester);
    final portion = find.descendant(
      of: find.byType(AppChoicePills<MealQuantityUnit>),
      matching: find.text('portion'),
    );
    await tester.ensureVisible(portion);
    await settle(tester);
    await tester.tap(portion);
    await settle(tester);
    await tester.enterText(field('Quantité (portions)'), '1');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Nouveau repas'),
      -240,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await capture(
      tester,
      '31c-repas-nouveau',
      shows: find.text('Nouveau repas'),
    );
  });

  testWidgets('programmes — liste et calendrier', (tester) async {
    // L'historique est NÉCESSAIRE à la dernière capture : la feuille d'une
    // case ne propose que des séances réellement faites ce jour-là, et sans
    // lui elle n'aurait rien à montrer.
    await pumpApp(
      tester,
      workouts: FakeWorkoutRepository()..history = historyOf(),
    );
    await goTab(tester, 'Training');
    await tester.tap(find.text('Programmes'));
    await settle(tester);
    await capture(tester, '32-programmes', shows: find.byType(ProgramsScreen));

    await tester.tap(find.text('Force en 2 semaines'));
    await settle(tester);
    await capture(
      tester,
      '33-programme-calendrier',
      shows: find.byType(ProgramDetailScreen),
    );

    // Et la grille POSÉE SUR DE VRAIES DATES : ce qui est fait, manqué, à
    // venir. L'exemple commence une semaine avant aujourd'hui, donc sa
    // semaine 1 a une histoire.
    await tester.tap(find.text('Voir le calendrier'));
    await settle(tester);
    await capture(
      tester,
      '34-programme-calendrier-date',
      shows: find.byType(ProgramCalendarScreen),
    );

    // La feuille d'une case, sur le cas qu'elle répare : le JEUDI manqué,
    // alors que l'historique porte bien une séance ce jour-là. C'est
    // exactement la personne qui s'est entraînée hors calendrier et dont la
    // case restait rouge sans recours.
    await tester.tap(find.byType(ProgramCalendarDayRow).at(3));
    await settle(tester);
    await capture(
      tester,
      '34b-calendrier-case',
      shows: find.byType(ProgramCalendarDaySheet),
    );
  });

  testWidgets('bibliothèque + fiche exercice', (tester) async {
    await pumpApp(tester);
    await openExercises(tester);
    await precacheMuscleImages(tester);
    // Premier étage : la grille des groupes musculaires.
    await capture(
      tester,
      '03-bibliotheque',
      shows: find.byType(MuscleGroupCard),
    );

    // Second étage : les mouvements du groupe choisi.
    await tester.tap(find.text('Tous les mouvements'));
    await settle(tester);
    await capture(
      tester,
      '19-bibliotheque-mouvements',
      shows: find.byType(ExerciseCard),
    );

    await tester.tap(find.widgetWithText(ExerciseCard, 'Squat'));
    await settle(tester);
    await capture(
      tester,
      '04-fiche-exercice',
      shows: find.byType(ExerciseDetailScreen),
    );
  });

  /// Un groupe musculaire garni : sa liste, puis la fiche d'un mouvement.
  Future<void> captureGroup(
    WidgetTester tester, {
    required String group,
    required String exercise,
    required String prefix,
  }) async {
    await pumpApp(tester, exercises: furnishedCatalogOf());
    await openExercises(tester);
    await precacheMuscleImages(tester);
    // La grille est PARESSEUSE : les groupes du bas ne sont pas construits
    // tant qu'on n'a pas défilé jusqu'à eux. Sans ça, « Triceps » restait
    // introuvable — mais seulement quand la capture du Dos l'avait précédée,
    // c'est-à-dire de façon intermittente.
    await tester.scrollUntilVisible(
      find.widgetWithText(MuscleGroupCard, group),
      240,
      scrollable: find.descendant(
        of: find.byType(MuscleGroupGrid),
        matching: find.byType(Scrollable),
      ),
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(MuscleGroupCard, group));
    await settle(tester);
    await capture(tester, '$prefix-liste', shows: find.byType(ExerciseCard));

    await tester.tap(find.widgetWithText(ExerciseCard, exercise));
    await settle(tester);
    await capture(
      tester,
      '$prefix-fiche',
      shows: find.byType(ExerciseDetailScreen),
    );
  }

  testWidgets('bibliothèque garnie — le groupe Dos', (tester) async {
    await captureGroup(
      tester,
      group: 'Dos',
      exercise: 'Tractions lestées',
      prefix: '20-dos',
    );
  });

  testWidgets('bibliothèque garnie — le groupe Triceps', (tester) async {
    await captureGroup(
      tester,
      group: 'Triceps',
      exercise: 'Dips',
      prefix: '22-triceps',
    );
  });

  testWidgets('bibliothèque garnie — le groupe Épaules', (tester) async {
    await captureGroup(
      tester,
      group: 'Épaules',
      exercise: 'Développé militaire',
      prefix: '24-epaules',
    );
  });

  testWidgets('bibliothèque garnie — le groupe Abdominaux', (tester) async {
    await captureGroup(
      tester,
      group: 'Abdominaux',
      exercise: 'Planche',
      prefix: '26-abdominaux',
    );
  });

  testWidgets('hub Training', (tester) async {
    await pumpApp(tester);
    await goTab(tester, 'Training');
    await capture(
      tester,
      '27-training-hub',
      shows: find.byType(TrainingHubScreen),
    );
  });

  testWidgets('Academy — leçons et question du jour', (tester) async {
    await pumpApp(tester);
    await goTab(tester, 'Academy');
    await capture(tester, '28-academy', shows: find.byType(AcademyScreen));
  });

  testWidgets('Academy — fiche d’anatomie dépliée', (tester) async {
    await pumpApp(tester);
    // Illustration de la leçon : décodage en temps réel avant capture.
    final context = tester.element(find.byType(AppBottomBar));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/academy/anatomie-pectoraux.webp'),
        context,
      ),
    );
    await goTab(tester, 'Academy');
    // Le défilement VERTICAL, nommé explicitement : l'écran porte aussi la
    // barre horizontale des domaines, et `Scrollable.last` tombait dessus —
    // la leçon ne remontait jamais, le harnais s'arrêtait là.
    await tester.scrollUntilVisible(
      find.text('Les pectoraux, un éventail'),
      150,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Les pectoraux, un éventail'));
    await settle(tester);
    await capture(tester, '36-academy-anatomie', shows: find.text('À RETENIR'));
  });

  testWidgets('Notification reçue application ouverte', (tester) async {
    // Une invitation arrive pendant qu'on est sur l'accueil : la popup
    // centrée la montre, au thème de l'application, et « Voir le défi »
    // mène au défi, comme la toucher dans la barrette.
    final messenger = FakePushMessenger(token: null);
    addTearDown(messenger.close);
    await pumpApp(tester, messenger: messenger);
    messenger.notices.add(
      const PushNotice(
        title: 'Nouveau défi',
        body: 'Léa te défie : Cinq séances cette semaine',
        destination: FriendChallengeDestination('exemple-defi-ami-seances'),
      ),
    );
    await settle(tester);
    await capture(
      tester,
      '35d-notification-recue',
      shows: find.text('Voir le défi'),
    );

    // L'action referme la popup elle-même : sa minuterie part avec elle.
    await tester.tap(find.text('Voir le défi'));
    await settle(tester);
    expect(find.byType(FriendChallengeScreen), findsOneWidget);
    expect(find.byType(AppPopupCard), findsNothing);
  });

  testWidgets('Message passager, sans voile', (tester) async {
    // Un simple message (ici, un geste abouti) : la même carte centrée,
    // mais SANS voile ; l'écran reste lisible et utilisable dessous.
    await pumpApp(tester);
    AppNotices.of(
      tester.element(find.byType(HomeScreen)),
    ).show('Série supprimée.', tone: AppNoticeTone.success);
    await settle(tester);
    await capture(
      tester,
      '35e-message-passager',
      shows: find.text('Série supprimée.'),
    );
    AppNotices.of(tester.element(find.byType(HomeScreen))).hide();
    await settle(tester);
  });

  testWidgets('Communauté — défis, ligue, amis', (tester) async {
    // Le harnais monte déjà le monde communauté en mémoire : amis,
    // encouragements, défis et une ligue en cours, sans réseau.
    await pumpApp(tester);
    await goTab(tester, 'Communauté');
    // L'onglet Défis s'ouvre le premier.
    await capture(tester, '29-communaute', shows: find.byType(CommunityScreen));

    // Plus bas : les défis ENTRE AMIS, qui ne se lisent pas comme une barre
    // de groupe mais comme un classement — un en cours, une invitation.
    // `AppSectionLabel` rend son texte en MAJUSCULES : c'est ce qui est à
    // l'écran, et donc ce qu'on cherche.
    await tester.scrollUntilVisible(
      find.text('DÉFIS ENTRE AMIS'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await capture(
      tester,
      '35-communaute-defis-amis',
      shows: find.text('DÉFIS ENTRE AMIS'),
    );

    // L'écran d'UN défi entre amis, d'après la maquette : l'invitation de
    // Léa, son message, les participants et la règle du jeu.
    Finder challengePage() => find
        .descendant(
          of: find.byType(FriendChallengeScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.tap(find.text('Cinq séances cette semaine'));
    await settle(tester);
    await capture(
      tester,
      '35b-defi-entre-amis',
      shows: find.text('Défi entre amis'),
    );
    await tester.scrollUntilVisible(
      find.text('Accepter le défi'),
      240,
      scrollable: challengePage(),
    );
    await settle(tester);
    await capture(
      tester,
      '35c-defi-entre-amis-bas',
      shows: find.text('Accepter le défi'),
    );
    tester.state<ScrollableState>(challengePage()).position.jumpTo(0);
    await settle(tester);
    await tester.tap(find.byType(AppBackButton));
    await settle(tester);

    // L'onglet LIGUE, d'après la maquette : la division et celle qui vient,
    // l'écart avec la zone de montée, le barème, le podium et MA ligne.
    await backToTop(tester);
    await tester.tap(find.text('Ligue'));
    await settle(tester);
    await capture(
      tester,
      '37-communaute-ligue',
      shows: find.text('Classement de la semaine'),
    );

    // Le bas de l'onglet : la bannière, et la sortie discrète.
    await tester.scrollUntilVisible(
      find.text('Quitter la ligue'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await capture(
      tester,
      '37a-communaute-ligue-bas',
      shows: find.text('grands résultats.'),
    );

    // Le classement COMPLET, dans sa feuille : toute la division, sans
    // nouvelle requête.
    await tester.tap(find.text('Voir le classement complet'));
    await settle(tester);
    await capture(
      tester,
      '37b-communaute-classement',
      shows: find.text('12 membres cette semaine'),
    );
    await tester.tapAt(const Offset(20, 40));
    await settle(tester);

    // Et l'autre visage de l'onglet : celui que TOUT LE MONDE voit d'abord,
    // puisque la ligue est un opt-in. Le classement y disparaît — on ne
    // montre pas des noms d'inconnus à qui n'a pas dit oui.
    await tester.tap(find.text('Quitter la ligue'));
    await settle(tester);
    // La confirmation de sortie a dit son mot : on la laisse partir, elle
    // masquerait l'invitation.
    AppNotices.of(tester.element(find.byType(CommunityScreen))).hide();
    await settle(tester);
    await backToTop(tester);
    await capture(
      tester,
      '38-communaute-ligue-invitation',
      shows: find.text('Rejoindre la ligue'),
    );

    // L'onglet AMIS, avec la loupe ouverte sur un prénom.
    await tester.tap(find.text('Amis'));
    await settle(tester);
    await capture(
      tester,
      '29b-communaute-amis',
      shows: find.text('DEMANDES REÇUES'),
    );
    await tester.tap(find.byTooltip('Rechercher'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'sar');
    await settle(tester);
    await capture(
      tester,
      '29c-communaute-recherche',
      shows: find.text('Chercher parmi tes amis'),
    );
  });

  testWidgets('séance active', (tester) async {
    final workouts = FakeWorkoutRepository()..active = activeWorkoutOf();
    await pumpApp(tester, workouts: workouts);
    // Le disque de reprise naît SOUS la barre flottante. Taper sans faire
    // défiler atteint la barre, pas le disque — c'est ainsi que cette
    // capture montrait la Progression.
    //
    // Il ne porte aucun texte depuis la refonte de l'accueil : on vise son
    // icône, dans la carte de séance et nulle part ailleurs.
    final resume = find.descendant(
      of: find.byType(TodayWorkoutCard),
      matching: find.byIcon(AppIcons.play),
    );
    await tester.scrollUntilVisible(
      resume,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(resume);
    await settle(tester);
    await capture(
      tester,
      '05-seance-active',
      shows: find.byType(ActiveWorkoutScreen),
    );

    // `testWidgets` refuse qu'un minuteur soit en cours à la fin du corps, et
    // il vérifie AVANT de démonter l'arbre. On démonte donc soi-même — ce qui
    // annule le chrono de séance — puis on laisse filer un instant : Drift
    // programme un `Timer.run` en fermant ses flux de requêtes, et un
    // `pump()` sans durée n'avance pas assez le temps fictif pour le purger.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('coach — depuis le hub Training', (tester) async {
    await pumpApp(tester, coach: coachOf(), premium: true);
    await openCoach(tester);
    await capture(tester, '18-coach', shows: find.byType(CoachScreen));
  });

  testWidgets('progression', (tester) async {
    await pumpApp(tester);
    await goTab(tester, 'Progrès');
    await capture(tester, '06-progression', shows: find.byType(ProgressScreen));

    await tester.scrollUntilVisible(
      find.byType(BodyWeightSection),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await capture(
      tester,
      '07-progression-poids',
      shows: find.byType(BodyWeightSection),
    );
  });

  testWidgets('abonnement premium', (tester) async {
    await pumpApp(tester, premium: true);
    await openProfileSettings(tester);
    await tester.tap(find.byType(ProfilePlanCard));
    await settle(tester);
    await capture(
      tester,
      '08-abonnement',
      shows: find.byType(SubscriptionScreen),
    );
  });

  testWidgets('nutrition — métabolisme complet', (tester) async {
    await pumpApp(tester);
    await openNutrition(tester);
    await capture(
      tester,
      '10-nutrition-metabolisme',
      shows: find.byType(NutritionScreen),
    );

    await tester.scrollUntilVisible(
      find.text('Macros'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await capture(tester, '11-nutrition-macros', shows: find.text('Macros'));
  });

  testWidgets('nutrition — profil à compléter', (tester) async {
    await pumpApp(tester, nutrition: nutritionOf(complete: false));
    await openNutrition(tester);
    await capture(
      tester,
      '12-nutrition-profil',
      shows: find.byType(NutritionScreen),
    );
  });

  testWidgets('profil + réglages + thème clair', (tester) async {
    await pumpApp(
      tester,
      premium: true,
      user: profileUser,
      lifetime: const LifetimeStats(completedSessions: 128, weeks: []),
      workouts: FakeWorkoutRepository()..history = historyOf(),
    );
    // L'illustration de « Toujours plus loin » : décodage en temps réel
    // avant capture, comme toute image du bundle.
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(
      () => precacheImage(const AssetImage(SummitIllustration.asset), context),
    );
    await openProfile(tester);
    await capture(tester, '13-profil', shows: find.byType(ProfileScreen));

    // Le bas du profil : les badges, les amis, « Toujours plus loin ».
    await tester.scrollUntilVisible(
      find.text('Toujours plus loin'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await capture(tester, '13a-profil-bas', shows: find.byType(ProfileScreen));

    // Les réglages vivent derrière le rouage de l'en-tête.
    await tester.tap(find.byTooltip('Réglages'));
    await settle(tester);
    await capture(
      tester,
      '13b-profil-reglages',
      shows: find.byType(ProfileSettingsScreen),
    );

    // Les réglages sont POUSSÉS par-dessus le profil et l'accueil : plusieurs
    // Scrollable cohabitent dans l'arbre, on vise celui de l'écran visible.
    await tester.scrollUntilVisible(
      find.text('Thème sombre'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    // Taper la LIGNE (pas l'interrupteur) ouvre l'écran d'apparence — seul
    // endroit où choisir « Système » ou « Sombre OLED ». On y bascule sur
    // « Clair » pour que la capture montre les réglages en thème clair,
    // fidèle au titre du test.
    await tester.tap(find.text('Thème sombre'));
    await settle(tester);
    await tester.tap(find.text('Clair'));
    await settle(tester);
    // « Sombre OLED » n'existe que sur cet écran-là ; l'étiquette de section,
    // elle, est rendue en capitales et se cherche mal au texte exact.
    await capture(tester, '14-reglages', shows: find.text('Sombre OLED'));
  });

  testWidgets('historique', (tester) async {
    final workouts = FakeWorkoutRepository()..history = historyOf();
    await pumpApp(tester, workouts: workouts);
    final context = tester.element(find.byType(AppBottomBar));
    unawaited(GoRouter.of(context).push(AppRoutes.history));
    await settle(tester);
    await capture(
      tester,
      '15-historique',
      shows: find.byType(WorkoutHistoryScreen),
    );
  });

  testWidgets('onboarding', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(AppBottomBar));
    // La première question montre les cartes d'identité illustrées :
    // décodage en temps réel avant capture, comme toute image du bundle.
    for (final profile in CarlysProfile.values) {
      final asset = carlysProfileContentOf(profile).assetPath;
      await tester.runAsync(() => precacheImage(AssetImage(asset), context));
    }
    GoRouter.of(context).go(AppRoutes.onboarding);
    await settle(tester);
    await capture(
      tester,
      '16-onboarding',
      shows: find.byType(OnboardingScreen),
    );
  });

  testWidgets('profils Carlys', (tester) async {
    await pumpApp(tester);
    // Illustrations des profils : décodage en temps réel avant capture,
    // comme toute image du bundle.
    final context = tester.element(find.byType(MaterialApp));
    for (final profile in CarlysProfile.values) {
      final asset = carlysProfileContentOf(profile).assetPath;
      await tester.runAsync(() => precacheImage(AssetImage(asset), context));
    }
    await settle(tester);
    await openProfileSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Mon profil'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(find.text('Mon profil'));
    await settle(tester);
    await capture(
      tester,
      '34-profils-carlys',
      shows: find.byType(CarlysProfilesScreen),
    );

    await tester.scrollUntilVisible(
      find.text('LE STRATÈGE'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.tap(find.text('LE STRATÈGE'));
    await settle(tester);
    await capture(
      tester,
      '35-profil-fiche',
      shows: find.text('« Je veux comprendre avant d’agir. »'),
    );
  });

  testWidgets('paywall exercice premium', (tester) async {
    final gated = _PremiumGated([summary('id-1', 'Balancier kettlebell')]);
    await pumpApp(tester, exercises: gated);
    await openExercises(tester);
    // La bibliothèque s'ouvre sur la grille des groupes musculaires.
    await tester.tap(
      find.widgetWithText(MuscleGroupCard, 'Tous les mouvements'),
    );
    await settle(tester);
    await tester.tap(find.text('Balancier kettlebell'));
    await settle(tester);
    await capture(
      tester,
      '09-exercice-premium',
      shows: find.byType(ExerciseDetailScreen),
    );
  });
}

class _PremiumGated extends FakeExercisesRepository {
  _PremiumGated(super.all) : super(pageSize: 10);

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) {
    return Future.error(
      const ForbiddenException('Exercice réservé aux membres Premium.'),
    );
  }
}
