import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/data/dto/coach_dtos.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_program_card.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La carte d'un programme proposé : les réglages en clair, et un geste qui
/// ne se confond jamais avec un second programme.
void main() {
  Future<void> pump(
    WidgetTester tester,
    CoachProgramProposal proposal, {
    VoidCallback? onOpen,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: CoachProgramCard(
            proposal: proposal,
            maxWidth: 320,
            onOpen: onOpen ?? () {},
          ),
        ),
      ),
    );
  }

  const proposal = CoachProgramProposal(
    id: 'p1',
    goal: TrainingGoal.strength,
    weeklySessions: 3,
    sessionMinutes: 45,
  );

  testWidgets('dit l’objectif et le rythme, puis propose de le créer', (
    tester,
  ) async {
    var opened = 0;
    await pump(tester, proposal, onOpen: () => opened++);

    expect(find.text('Force'), findsOneWidget);
    expect(find.text('3 séances par semaine · 45 min'), findsOneWidget);
    await tester.tap(find.text('Créer ce programme'));
    expect(opened, 1);
  });

  testWidgets('déjà créé : ramène au programme', (tester) async {
    await pump(
      tester,
      const CoachProgramProposal(
        id: 'p1',
        goal: TrainingGoal.strength,
        weeklySessions: 1,
        sessionMinutes: 30,
        acceptedProgramId: 'prog-1',
      ),
    );

    expect(find.text('Voir le programme'), findsOneWidget);
    expect(find.text('1 séance par semaine · 30 min'), findsOneWidget);
  });

  test('se lit depuis le serveur ; un objectif inconnu ne s’affiche pas', () {
    final message = coachMessageFromJson({
      'id': 'm1',
      'role': 'ASSISTANT',
      'content': 'Voilà.',
      'programProposal': {
        'id': 'p1',
        'goal': 'MARATHON',
        'weeklySessions': 4,
        'sessionMinutes': 60,
        'acceptedProgramId': null,
      },
    });
    expect(message.programProposal?.goal, TrainingGoal.marathon);
    expect(message.programProposal?.weeklySessions, 4);

    expect(
      coachProgramProposalFromJson({
        'id': 'p1',
        'goal': 'YOGA',
        'weeklySessions': 4,
        'sessionMinutes': 60,
      }),
      isNull,
    );
  });
}
