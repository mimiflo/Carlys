import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/session_plan.dart';
import 'package:carlys_mobile/features/workout_template/presentation/controllers/session_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

/// Traduction du plan en consigne d'écran — logique pure, testée sans widget.
void main() {
  SessionPlanItem item(
    String id, {
    required int exercisePosition,
    required String exerciseName,
    required int setPosition,
    int? targetReps,
    double? targetWeightKg,
    int? restSeconds,
    String? doneSetId,
    bool skipped = false,
  }) => SessionPlanItem(
    id: id,
    sessionId: 's-1',
    exercisePosition: exercisePosition,
    exerciseId: 'ex-$exercisePosition',
    exerciseName: exerciseName,
    setPosition: setPosition,
    targetReps: targetReps,
    targetWeightKg: targetWeightKg,
    restSeconds: restSeconds,
    doneSetId: doneSetId,
    skipped: skipped,
  );

  /// Deux exercices : « Développé couché » 3 × 8 à 60 kg, puis « Dips » 2 × 10.
  SessionPlan planOf({String? doneSetId}) => SessionPlan(
    sessionId: 's-1',
    templateName: 'Push force',
    items: [
      item(
        'p-1',
        exercisePosition: 0,
        exerciseName: 'Développé couché',
        setPosition: 0,
        targetReps: 8,
        targetWeightKg: 60,
        restSeconds: 120,
        doneSetId: doneSetId,
      ),
      item(
        'p-2',
        exercisePosition: 0,
        exerciseName: 'Développé couché',
        setPosition: 1,
        targetReps: 8,
        targetWeightKg: 60,
        restSeconds: 120,
      ),
      item(
        'p-3',
        exercisePosition: 0,
        exerciseName: 'Développé couché',
        setPosition: 2,
        targetReps: 6,
        targetWeightKg: 70,
        restSeconds: 150,
      ),
      item(
        'p-4',
        exercisePosition: 1,
        exerciseName: 'Dips',
        setPosition: 0,
        targetReps: 10,
      ),
    ],
  );

  test('sans choix manuel : la consigne suit le programme', () {
    final guidance = guidanceFor(planOf());

    expect(guidance.templateName, 'Push force');
    expect(guidance.planItemId, 'p-1');
    expect(guidance.overline, 'Série 1 sur 3 · Développé couché');
    expect(guidance.targetReps, 8);
    expect(guidance.targetWeightKg, 60);
    expect(guidance.restSeconds, 120);
    expect(guidance.exercisePosition, 0);
    // 4 items prévus, celui en cours de saisie ne compte pas deux fois.
    expect(guidance.upcomingInSession, 3);
    expect(guidance.upcomingInExercise, 2);
    expect(guidance.summary, '0 série sur 4 prévues');
  });

  test('après une série honorée : « Série 2 sur 3 »', () {
    final guidance = guidanceFor(planOf(doneSetId: 'set-1'));

    expect(guidance.planItemId, 'p-2');
    expect(guidance.overline, 'Série 2 sur 3 · Développé couché');
    expect(guidance.doneCount, 1);
    expect(guidance.upcomingInSession, 2);
    expect(guidance.upcomingInExercise, 1);
    expect(guidance.summary, '1 série sur 4 prévues');
  });

  test('choix manuel d’un exercice du programme : l’appariement le suit', () {
    final guidance = guidanceFor(
      planOf(),
      pickedExerciseName: 'Dips',
      pickedExerciseId: 'ex-1',
    );

    expect(guidance.planItemId, 'p-4');
    expect(guidance.overline, 'Série 1 sur 1 · Dips');
    expect(guidance.exercisePosition, 1);
    expect(guidance.upcomingInExercise, 0);
  });

  test('exercice hors programme : aucune cible, aucun exercice à passer', () {
    final guidance = guidanceFor(
      planOf(),
      pickedExerciseName: 'Curl haltères',
      pickedExerciseId: 'ex-99',
    );

    // Aucun item honoré, aucune cible, et surtout AUCUNE position d'exercice :
    // « Passer cet exercice » ne doit jamais sauter un autre exercice que
    // celui affiché.
    expect(guidance.planItemId, isNull);
    expect(guidance.overline, isNull);
    expect(guidance.targetReps, isNull);
    expect(guidance.exercisePosition, isNull);
    expect(guidance.exerciseName, isNull);

    // Le dénominateur ne bouge pas : une série en trop n'est pas un écart.
    expect(guidance.totalCount, 4);
    expect(guidance.upcomingInSession, 4);
  });

  test('programme terminé : la séance continue librement', () {
    final plan = SessionPlan(
      sessionId: 's-1',
      templateName: 'Push force',
      items: [
        item(
          'p-1',
          exercisePosition: 0,
          exerciseName: 'Développé couché',
          setPosition: 0,
          targetReps: 8,
          doneSetId: 'set-1',
        ),
        item(
          'p-2',
          exercisePosition: 0,
          exerciseName: 'Développé couché',
          setPosition: 1,
          targetReps: 8,
          skipped: true,
        ),
      ],
    );

    final guidance = guidanceFor(plan);

    expect(guidance.planItemId, isNull);
    expect(guidance.exercisePosition, isNull);
    expect(guidance.upcomingInSession, 0);
    // Un constat, jamais un reproche.
    expect(guidance.summary, '1 série sur 2 prévues');
  });

  test('la nature de la série prévue est conservée', () {
    final plan = SessionPlan(
      sessionId: 's-1',
      templateName: 'Push',
      items: [
        SessionPlanItem(
          id: 'p-1',
          sessionId: 's-1',
          exercisePosition: 0,
          exerciseName: 'Développé couché',
          setPosition: 0,
          kind: SetKind.warmup,
          targetReps: 12,
          targetWeightKg: 40,
        ),
      ],
    );

    expect(
      plan.nextPendingFor(exerciseName: 'développé couché')!.kind,
      SetKind.warmup,
    );
  });
}
