import {
  type PersonalRecord,
  type WorkoutSessionSummary,
  type WorkoutTemplateDetail,
} from '@carlys/api-contracts';
import {
  coachBodyMetricView,
  coachRecordView,
  coachSessionView,
  coachTemplateView,
} from './coach-views';

/**
 * Ce que le coach relit à chaque tour d'outil. Sur un processeur, chaque
 * jeton relu coûte du temps de réponse : les identifiants qu'il n'utilise
 * jamais et les champs vides partent, ce qu'il doit citer ou réutiliser
 * (exerciseId, templateId, valeurs) reste.
 */
describe('vues du coach', () => {
  const uuid = (n: number) => `0000000${n}-aaaa-4bbb-8ccc-dddddddddddd`;

  const session: WorkoutSessionSummary = {
    id: uuid(1),
    name: 'Haut du corps',
    status: 'COMPLETED',
    startedAt: '2026-09-29T18:04:12.345Z',
    endedAt: '2026-09-29T19:01:00.000Z',
    durationSeconds: 3420,
    setsCount: 18,
    totalVolumeKg: 8450,
    templateId: uuid(2),
    templateName: 'Push A',
    programDayId: uuid(3),
    revision: 7,
  };

  it('une séance : ce qui s’est passé, sans les identifiants internes', () => {
    expect(coachSessionView(session)).toEqual({
      name: 'Haut du corps',
      status: 'COMPLETED',
      startedAt: '2026-09-29T18:04Z',
      durationMin: 57,
      setsCount: 18,
      totalVolumeKg: 8450,
      templateName: 'Push A',
    });
  });

  it('un record garde son exercice (réutilisable dans une proposition)', () => {
    const record: PersonalRecord = {
      id: uuid(4),
      exerciseId: uuid(5),
      exerciseName: 'Développé couché',
      recordType: 'MAX_WEIGHT',
      value: 100,
      reps: 3,
      weightKg: 100,
      achievedAt: '2026-09-20T17:00:00.000Z',
    };
    expect(coachRecordView(record)).toEqual({
      exerciseId: uuid(5),
      exerciseName: 'Développé couché',
      recordType: 'MAX_WEIGHT',
      value: 100,
      reps: 3,
      weightKg: 100,
      achievedAt: '2026-09-20',
    });
  });

  it('une pesée : la valeur et le jour, rien d’autre', () => {
    expect(
      coachBodyMetricView({
        id: uuid(9),
        metricType: 'WEIGHT_KG',
        value: 82.4,
        measuredAt: '2026-09-28T07:12:43.512Z',
      }),
    ).toEqual({ value: 82.4, measuredAt: '2026-09-28' });
  });

  it('un modèle : ses exercices et séries, sans identifiants ni champs vides', () => {
    const template: WorkoutTemplateDetail = {
      id: uuid(6),
      name: 'Push A',
      exercisesCount: 1,
      plannedSetsCount: 2,
      estimatedDurationMinutes: 45,
      previewExerciseNames: ['Développé couché'],
      lastUsedAt: null,
      updatedAt: '2026-09-01T00:00:00.000Z',
      createdAt: '2026-08-01T00:00:00.000Z',
      notes: null,
      exercises: [
        {
          id: uuid(7),
          exerciseId: uuid(5),
          exerciseName: 'Développé couché',
          position: 0,
          notes: null,
          sets: [
            {
              id: uuid(8),
              position: 0,
              kind: 'NORMAL',
              targetReps: 8,
              targetWeightKg: 60,
              targetDurationSeconds: null,
              targetDistanceMeters: null,
              restSeconds: 90,
            },
          ],
        },
      ],
    };

    const view = coachTemplateView(template);

    expect(view).toEqual({
      id: uuid(6),
      name: 'Push A',
      estimatedDurationMinutes: 45,
      exercises: [
        {
          exerciseId: uuid(5),
          exerciseName: 'Développé couché',
          sets: [{ kind: 'NORMAL', targetReps: 8, targetWeightKg: 60, restSeconds: 90 }],
        },
      ],
    });
    // Le gain se mesure : la vue pèse moins de la moitié du contrat d'écran.
    expect(JSON.stringify(view).length).toBeLessThan(JSON.stringify(template).length / 2);
  });
});
