import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_goal_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/training_goal_providers.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/training_profile_providers.dart';
import 'package:carlys_mobile/features/workout_program/presentation/screens/training_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercises_repository.dart';
import '../../support/fake_training_goal_repository.dart';
import '../../support/fake_training_profile_repository.dart';

/// Une session ouverte dont le rafraîchissement relit l'objectif ÉCRIT.
class _Session extends AuthController {
  _Session(this._goals);

  final FakeTrainingGoalRepository _goals;
  bool failRefresh = false;

  @override
  AuthState build() => const AuthAuthenticated(user: fakeUser);

  @override
  Future<void> refreshProfile() async {
    if (failRefresh) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
    state = AuthAuthenticated(
      user: AuthUser(
        id: fakeUser.id,
        email: fakeUser.email,
        displayName: fakeUser.displayName,
        emailVerified: true,
        locale: fakeUser.locale,
        timezone: fakeUser.timezone,
        trainingGoal: _goals.chosen.lastOrNull,
      ),
    );
  }
}

/// Les choix de « Préparer mon programme » se voient SOUS LE DOIGT : avant,
/// chacun attendait l'écriture PUIS une relecture — deux allers-retours de
/// délai sur la page. Le serveur confirme ensuite, ou l'écran se remet.
void main() {
  late FakeTrainingGoalRepository goals;
  late FakeTrainingProfileRepository profiles;
  late ProviderContainer container;

  setUp(() async {
    goals = FakeTrainingGoalRepository()..gate = Completer<void>();
    profiles = FakeTrainingProfileRepository(
      initial: const TrainingProfile(
        goal: null,
        experience: null,
        weeklySessionsTarget: 3,
        sessionMinutesTarget: 45,
        equipmentSlugs: ['halteres'],
      ),
    );
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => _Session(goals)),
        trainingGoalRepositoryProvider.overrideWithValue(goals),
        trainingProfileRepositoryProvider.overrideWithValue(profiles),
        exercisesRepositoryProvider.overrideWithValue(
          FakeExercisesRepository(const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(trainingProfileProvider, (_, _) {});
    await container.read(trainingProfileProvider.future);
  });

  TrainingProfile shown() => container.read(trainingProfileProvider).value!;

  test('l’objectif se voit avant la réponse, et y reste', () async {
    final choix = container
        .read(trainingGoalActionsProvider)
        .choose(TrainingGoal.hyrox);

    expect(container.read(currentTrainingGoalProvider), TrainingGoal.hyrox);
    goals.gate!.complete();
    await choix;
    expect(container.read(currentTrainingGoalProvider), TrainingGoal.hyrox);
  });

  test('un objectif refusé s’efface, l’échec remonte', () async {
    goals.failChoose = true;
    final choix = container
        .read(trainingGoalActionsProvider)
        .choose(TrainingGoal.hyrox);
    expect(container.read(currentTrainingGoalProvider), TrainingGoal.hyrox);

    goals.gate!.complete();
    await expectLater(choix, throwsA(anything));
    expect(container.read(currentTrainingGoalProvider), isNull);
  });

  test(
    'deux objectifs d’affilée : le dernier tient, le serveur aussi',
    () async {
      final actions = container.read(trainingGoalActionsProvider);
      final premier = actions.choose(TrainingGoal.hyrox);
      final second = actions.choose(TrainingGoal.fatLoss);
      expect(container.read(currentTrainingGoalProvider), TrainingGoal.fatLoss);

      goals.gate!.complete();
      await premier;
      expect(container.read(currentTrainingGoalProvider), TrainingGoal.fatLoss);
      await second;
      expect(goals.chosen, [TrainingGoal.hyrox, TrainingGoal.fatLoss]);
      expect(container.read(currentTrainingGoalProvider), TrainingGoal.fatLoss);
    },
  );

  test('le rythme se voit avant la réponse, sans relecture après', () async {
    profiles.gate = Completer<void>();
    final fetchesAvant = profiles.fetches;
    final geste = container
        .read(trainingProfileActionsProvider)
        .setWeeklySessions(5);

    expect(shown().weeklySessionsTarget, 5);
    profiles.gate!.complete();
    await geste;
    expect(shown().weeklySessionsTarget, 5);
    expect(profiles.profile.weeklySessionsTarget, 5);
    // La réponse du PATCH suffit : pas un aller-retour de plus.
    expect(profiles.fetches, fetchesAvant);
  });

  test('une écriture refusée remet l’état serveur', () async {
    profiles
      ..gate = Completer<void>()
      ..failPatch = true;
    final geste = container
        .read(trainingProfileActionsProvider)
        .setSessionMinutes(90);
    expect(shown().sessionMinutesTarget, 90);

    profiles.gate!.complete();
    await expectLater(geste, throwsA(anything));
    await container.read(trainingProfileProvider.future);
    expect(shown().sessionMinutesTarget, 45);
  });

  test(
    'deux coches de matériel se voient aussitôt, toutes deux écrites',
    () async {
      profiles.gate = Completer<void>();
      final actions = container.read(trainingProfileActionsProvider);
      final barre = actions.toggleEquipment('barre');
      final banc = actions.toggleEquipment('banc');

      expect(shown().equipmentSlugs.toSet(), {'halteres', 'barre', 'banc'});
      profiles.gate!.complete();
      await barre;
      await banc;
      expect(profiles.profile.equipmentSlugs.toSet(), {
        'halteres',
        'barre',
        'banc',
      });
      expect(shown().equipmentSlugs.toSet(), {'halteres', 'barre', 'banc'});
    },
  );

  test(
    'hors ligne, un refus revient à l’état serveur même sans relecture',
    () async {
      // PATCH refusé ET relecture refusée : Riverpod garderait la dernière
      // valeur — le choix refusé — dans l'erreur.
      profiles
        ..gate = Completer<void>()
        ..failPatch = true
        ..failFetch = true;
      final geste = container
          .read(trainingProfileActionsProvider)
          .setSessionMinutes(90);
      expect(shown().sessionMinutesTarget, 90);

      profiles.gate!.complete();
      await expectLater(geste, throwsA(anything));
      await expectLater(
        container.read(trainingProfileProvider.future),
        throwsA(anything),
      );
      expect(
        container
            .read(trainingProfileProvider)
            .valueOrNull
            ?.sessionMinutesTarget,
        45,
      );
    },
  );

  test(
    'une coche pendant une relecture attend sa fin, rien ne se perd',
    () async {
      profiles.gate = Completer<void>();
      final actions = container.read(trainingProfileActionsProvider);
      // Une relecture en vol, qui reviendra avec l'état d'AVANT.
      container.invalidate(trainingProfileProvider);
      final barre = actions.toggleEquipment('barre');
      await container.read(trainingProfileProvider.future);
      final banc = actions.toggleEquipment('banc');
      profiles.gate!.complete();
      await barre;
      await banc;

      expect(profiles.profile.equipmentSlugs.toSet(), {
        'halteres',
        'barre',
        'banc',
      });
    },
  );

  test('objectif écrit mais session non relue : il reste, puis cède à la '
      'relecture suivante', () async {
    final session = container.read(authControllerProvider.notifier) as _Session
      ..failRefresh = true;
    final choix = container
        .read(trainingGoalActionsProvider)
        .choose(TrainingGoal.hyrox);
    goals.gate!.complete();
    await choix;
    expect(container.read(currentTrainingGoalProvider), TrainingGoal.hyrox);

    // Plus tard, la session se relit (reprise de l'appli, autre appareil).
    session.failRefresh = false;
    goals.chosen
      ..clear()
      ..add(TrainingGoal.fatLoss);
    await session.refreshProfile();
    expect(container.read(currentTrainingGoalProvider), TrainingGoal.fatLoss);
  });

  testWidgets('la feuille se ferme dès le choix, la carte le montre déjà', (
    tester,
  ) async {
    // La porte du `setUp` est née hors de la zone du banc de widgets : sa
    // complétion n'y serait jamais pompée.
    goals.gate = Completer<void>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const TrainingSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir mon objectif'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hyrox'));
    // Le serveur n'a PAS répondu (la porte est fermée).
    await tester.pumpAndSettle();

    expect(find.text('Ton objectif d’entraînement'), findsNothing);
    expect(find.text('Hyrox'), findsOneWidget);
    goals.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Objectif retenu : Hyrox.'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
