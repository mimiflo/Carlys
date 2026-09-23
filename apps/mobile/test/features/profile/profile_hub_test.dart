import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/dashboard/domain/entities/consistency_week.dart';
import 'package:carlys_mobile/features/dashboard/presentation/providers/home_day_providers.dart';
import 'package:carlys_mobile/features/profile/presentation/providers/profile_hub_providers.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_identity_card.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_objective_card.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_program_card.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/program_advancement.dart';
import 'package:carlys_mobile/features/workout_program/presentation/controllers/training_goal_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE PROFIL RACONTE, ET NE MENT PAS PAR OMISSION.
///
/// Chaque carte du profil est testée dans ses états : servie, en route,
/// hors ligne, vide. La règle qui les relie : un chiffre ou un état qu'on
/// ne connaît pas ne s'affiche JAMAIS comme un zéro ou une absence.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  group('identité', () {
    final camille = AuthUser(
      id: 'user-1',
      email: 'camille@example.com',
      displayName: 'Camille',
      emailVerified: true,
      locale: 'fr',
      timezone: 'Europe/Paris',
      carlysProfile: CarlysProfile.challenger,
      createdAt: DateTime.utc(2024, 3, 12, 9),
    );

    List<Override> chiffres({
      AsyncValue<int> sessions = const AsyncData(128),
      AsyncValue<int> friends = const AsyncData(12),
    }) => [
      consistencyWeekProvider.overrideWith(
        (ref) => const ConsistencyWeek(days: [], streakDays: 36),
      ),
      profileSessionsCountProvider.overrideWith((ref) => sessions),
      profileFriendsCountProvider.overrideWith((ref) => friends),
    ];

    testWidgets('nom, ancienneté, phrase du profil Carlys et trois chiffres', (
      tester,
    ) async {
      await pump(
        tester,
        ProfileIdentityCard(user: camille, onOpen: () {}),
        overrides: chiffres(),
      );

      expect(find.text('Camille'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('Membre depuis mars 2024'), findsOneWidget);
      expect(find.text('« Je veux aller plus loin. »'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('jours consécutifs'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('séances effectuées'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('amis'), findsOneWidget);
    });

    testWidgets('sans date ni profil choisi : les lignes s’effacent', (
      tester,
    ) async {
      const neuf = AuthUser(
        id: 'user-2',
        email: 'sam@example.com',
        displayName: 'Sam',
        emailVerified: true,
        locale: 'fr',
        timezone: 'Europe/Paris',
      );
      await pump(
        tester,
        ProfileIdentityCard(user: neuf, onOpen: () {}),
        overrides: chiffres(),
      );

      expect(find.textContaining('Membre depuis'), findsNothing);
      expect(find.textContaining('«'), findsNothing);
    });

    testWidgets('hors ligne : un tiret, jamais un zéro', (tester) async {
      await pump(
        tester,
        ProfileIdentityCard(user: camille, onOpen: () {}),
        overrides: chiffres(
          sessions: const AsyncError(
            NetworkException('socket'),
            StackTrace.empty,
          ),
          friends: const AsyncLoading(),
        ),
      );

      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0'), findsNothing);
      // La série est locale : elle, reste dite.
      expect(find.text('36'), findsOneWidget);
    });

    testWidgets('un seul : le singulier, et zéro aussi', (tester) async {
      await pump(
        tester,
        ProfileIdentityCard(user: camille, onOpen: () {}),
        overrides: chiffres(
          sessions: const AsyncData(1),
          friends: const AsyncData(0),
        ),
      );

      expect(find.text('séance effectuée'), findsOneWidget);
      expect(find.text('ami'), findsOneWidget);
    });
  });

  group('objectif', () {
    const avancement = ProgramAdvancement(
      phase: ProgramPhase.running,
      weekNumber: 2,
      weeksCount: 8,
      elapsedDays: 13,
      totalDays: 56,
      daysUntilStart: 0,
    );

    testWidgets('la jauge dit la semaine, puis un pourcentage et sa base', (
      tester,
    ) async {
      await pump(
        tester,
        ProfileObjectiveCard(onTap: () {}),
        overrides: [
          currentTrainingGoalProvider.overrideWith(
            (ref) => TrainingGoal.muscleGain,
          ),
          activeProgramAdvancementProvider.overrideWith(
            (ref) => const AsyncData(avancement),
          ),
        ],
      );

      expect(find.text('Prise de muscle'), findsOneWidget);
      expect(find.text('Semaine 2 sur 8'), findsOneWidget);
      expect(find.text('23\u00A0%'), findsOneWidget);
      // Le pourcentage NOMME SA BASE (docs/product/progression.md).
      expect(find.text('du programme'), findsOneWidget);
      expect(find.byType(AppGauge), findsOneWidget);
    });

    testWidgets('sans programme daté : pas de jauge, jamais une barre vide', (
      tester,
    ) async {
      await pump(
        tester,
        ProfileObjectiveCard(onTap: () {}),
        overrides: [
          currentTrainingGoalProvider.overrideWith((ref) => null),
          activeProgramAdvancementProvider.overrideWith(
            (ref) => const AsyncData(null),
          ),
        ],
      );

      expect(find.text('À choisir'), findsOneWidget);
      expect(find.byType(AppGauge), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('programme', () {
    final plan = ProgramDetail(
      id: 'p-1',
      name: 'Programme intermédiaire',
      weeksCount: 8,
      isActive: true,
      days: [
        for (var week = 1; week <= 8; week++)
          for (final day in [1, 2, 4, 5])
            ProgramDayEntry(
              id: 'j-$week-$day',
              weekNumber: week,
              dayOfWeek: day,
              label: 'Séance',
              isRest: false,
            ),
      ],
    );

    Future<void> pumpProgram(
      WidgetTester tester,
      Future<ProgramDetail?> Function() source, {
      ValueChanged<String>? onOpen,
      VoidCallback? onBrowse,
    }) => pump(
      tester,
      ProfileProgramCard(
        onOpenProgram: onOpen ?? (_) {},
        onBrowse: onBrowse ?? () {},
      ),
      overrides: [activeProgramProvider.overrideWith((ref) => source())],
    );

    testWidgets('le programme suivi : son nom et son rythme', (tester) async {
      String? ouvert;
      await pumpProgram(tester, () async => plan, onOpen: (id) => ouvert = id);
      await tester.pump();

      expect(find.text('Programme intermédiaire'), findsOneWidget);
      expect(find.text('4 séances par semaine · 8 semaines'), findsOneWidget);

      await tester.tap(find.text('Mon programme'));
      expect(ouvert, 'p-1');
    });

    testWidgets('aucun programme : une invitation vers la liste', (
      tester,
    ) async {
      var parcouru = false;
      await pumpProgram(
        tester,
        () async => null,
        onBrowse: () => parcouru = true,
      );
      await tester.pump();

      expect(find.text('Aucun programme suivi'), findsOneWidget);
      await tester.tap(find.text('Mon programme'));
      expect(parcouru, isTrue);
    });

    testWidgets('hors ligne : dit tel quel, jamais « aucun programme »', (
      tester,
    ) async {
      await pumpProgram(
        tester,
        () async => throw const NetworkException('socket'),
      );
      await tester.pump();

      expect(find.text('Hors connexion'), findsOneWidget);
      expect(find.text('Aucun programme suivi'), findsNothing);
    });
  });
}
