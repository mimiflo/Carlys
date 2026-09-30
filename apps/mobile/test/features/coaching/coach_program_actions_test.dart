import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/providers/coach_program_actions.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/program_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/training_goal_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_coach_repository.dart';
import '../../support/fake_program_repository.dart';
import '../../support/fake_training_profile_repository.dart';

/// Objectif retenu, sans rafraîchir une session qui n'existe pas en test.
class _RecordingGoalActions extends TrainingGoalActions {
  _RecordingGoalActions(super.ref);

  final List<TrainingGoal> chosen = [];

  @override
  Future<void> choose(TrainingGoal goal) async => chosen.add(goal);
}

/// Accepter un programme proposé : les trois réglages sur le profil, le
/// programme engendré par Carlys, l'acceptation notée — et jamais deux fois.
void main() {
  late FakeTrainingProfileRepository profile;
  late FakeProgramRepository programs;
  late FakeCoachRepository coach;
  late _RecordingGoalActions goals;

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        trainingGoalActionsProvider.overrideWith((ref) {
          return goals = _RecordingGoalActions(ref);
        }),
        trainingProfileRepositoryProvider.overrideWithValue(profile),
        programRepositoryProvider.overrideWithValue(programs),
        coachRepositoryProvider.overrideWithValue(coach),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    profile = FakeTrainingProfileRepository();
    programs = FakeProgramRepository();
    coach = FakeCoachRepository();
  });

  const proposal = CoachProgramProposal(
    id: 'prop-1',
    goal: TrainingGoal.strength,
    weeklySessions: 3,
    sessionMinutes: 45,
  );

  test('pose les réglages, engendre, et note l’acceptation', () async {
    final programId = await container()
        .read(coachProgramActionsProvider)
        .start(proposal);

    expect(goals.chosen, [TrainingGoal.strength]);
    expect(profile.profile.weeklySessionsTarget, 3);
    expect(profile.profile.sessionMinutesTarget, 45);
    expect(await programs.byId(programId), isNotNull);
    expect(coach.acceptedPrograms.single, (
      proposalId: 'prop-1',
      programId: programId,
    ));
  });

  test('déjà acceptée : ramène au programme, sans rien écrire', () async {
    const accepted = CoachProgramProposal(
      id: 'prop-1',
      goal: TrainingGoal.strength,
      weeklySessions: 3,
      sessionMinutes: 45,
      acceptedProgramId: 'programme-existant',
    );

    final programId = await container()
        .read(coachProgramActionsProvider)
        .start(accepted);

    expect(programId, 'programme-existant');
    expect(profile.profile.weeklySessionsTarget, isNull);
    expect(coach.acceptedPrograms, isEmpty);
  });

  test(
    'profil incomplet : le refus du serveur remonte, rien n’est noté',
    () async {
      programs.generationFailure = const ValidationException(
        'Complète ton profil d’entraînement avant de générer.',
      );

      await expectLater(
        container().read(coachProgramActionsProvider).start(proposal),
        throwsA(isA<ValidationException>()),
      );
      expect(coach.acceptedPrograms, isEmpty);
    },
  );

  test(
    'acceptation non notée : le programme existe, on y va quand même',
    () async {
      coach.programAcceptError = const NetworkException('coupure');

      final programId = await container()
          .read(coachProgramActionsProvider)
          .start(proposal);

      expect(await programs.byId(programId), isNotNull);
      expect(coach.acceptedPrograms, isEmpty);
    },
  );
}
