import 'package:carlys_mobile/features/coaching/data/dto/coach_dtos.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lecture d'une proposition.
///
/// L'API renvoie des séries **à plat** ; l'écran affiche des exercices. La
/// bascule se fait ici, une fois, et elle doit garder les deux vues cohérentes :
/// celle qu'on lit et celle qu'on lance.
void main() {
  Map<String, dynamic> set({
    required String id,
    required int exercisePosition,
    required String exerciseName,
    required int setPosition,
    String kind = 'NORMAL',
    int? targetReps,
    double? targetWeightKg,
  }) {
    return <String, dynamic>{
      'id': id,
      'exercisePosition': exercisePosition,
      'exerciseId': 'ex-$exercisePosition',
      'exerciseName': exerciseName,
      'setPosition': setPosition,
      'kind': kind,
      'targetReps': targetReps,
      'targetWeightKg': targetWeightKg,
      'restSeconds': 90,
    };
  }

  Map<String, dynamic> proposal(List<Map<String, dynamic>> items) => {
        'id': 'p1',
        'name': 'Haut du corps',
        'estimatedMinutes': 28,
        'sourceTemplateId': null,
        'acceptedSessionId': null,
        'items': items,
      };

  test('les séries se regroupent par exercice, dans l’ordre du plan', () {
    // Volontairement désordonné : le serveur n'a aucune obligation de trier.
    final parsed = coachProposalFromJson(
      proposal([
        set(
          id: 's3',
          exercisePosition: 1,
          exerciseName: 'Tractions',
          setPosition: 0,
          targetReps: 6,
        ),
        set(
          id: 's2',
          exercisePosition: 0,
          exerciseName: 'Développé couché',
          setPosition: 1,
          targetReps: 8,
          targetWeightKg: 60,
        ),
        set(
          id: 's1',
          exercisePosition: 0,
          exerciseName: 'Développé couché',
          setPosition: 0,
          targetReps: 8,
          targetWeightKg: 60,
        ),
      ]),
    );

    expect(parsed.exercises.map((it) => it.name), [
      'Développé couché',
      'Tractions',
    ]);
    expect(parsed.exercises.first.setCount, 2);
    expect(parsed.exercises.first.detail, '8 reps · 60 kg');
    expect(parsed.exercises.last.detail, '6 reps');

    // La vue exécutable garde TOUTES les séries, triées : c'est elle qui
    // devient le plan de la séance.
    expect(parsed.sets, hasLength(3));
    expect(parsed.sets.map((it) => it.id), ['s1', 's2', 's3']);
  });

  test('le résumé décrit une série normale, pas l’échauffement', () {
    final parsed = coachProposalFromJson(
      proposal([
        set(
          id: 's1',
          exercisePosition: 0,
          exerciseName: 'Squat',
          setPosition: 0,
          kind: 'WARMUP',
          targetReps: 10,
          targetWeightKg: 20,
        ),
        set(
          id: 's2',
          exercisePosition: 0,
          exerciseName: 'Squat',
          setPosition: 1,
          targetReps: 5,
          targetWeightKg: 100,
        ),
      ]),
    );

    expect(parsed.exercises.single.detail, '5 reps · 100 kg');
    expect(parsed.sets.first.kind, SetKind.warmup);
  });

  test('sans cible, le résumé reste vide plutôt qu’inventé', () {
    final parsed = coachProposalFromJson(
      proposal([
        set(
          id: 's1',
          exercisePosition: 0,
          exerciseName: 'Gainage',
          setPosition: 0,
        ),
      ]),
    );

    expect(parsed.exercises.single.detail, isEmpty);
  });

  test('une proposition déjà lancée porte sa séance', () {
    final json = proposal([
      set(
        id: 's1',
        exercisePosition: 0,
        exerciseName: 'Squat',
        setPosition: 0,
        targetReps: 5,
      ),
    ])
      ..['acceptedSessionId'] = 'session-42';

    final parsed = coachProposalFromJson(json);

    expect(parsed.isAccepted, isTrue);
    expect(parsed.acceptedSessionId, 'session-42');
  });
}
