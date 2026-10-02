import { NotFoundException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { type WorkoutTemplatesService } from '../../workout_templates/application/workout-templates.service';
import { type CoachRepository } from '../infrastructure/coach.repository';
import { CoachWorkoutCreator } from './coach-workout-creator';

const USER = 'utilisateur-1';
const PROPOSAL = 'proposition-1';

const set = (id: string, exercisePosition: number, setPosition: number, exerciseId: string) => ({
  id,
  exercisePosition,
  setPosition,
  exerciseId,
  exerciseName: exerciseId,
  kind: 'NORMAL' as const,
  targetReps: 10,
  targetWeightKg: null,
  restSeconds: 60,
});

function build(existing: unknown = null) {
  const templates = {
    templateDetail: existing
      ? jest.fn().mockResolvedValue(existing)
      : jest.fn().mockRejectedValue(new NotFoundException()),
    saveTemplate: jest.fn((_user: string, id: string, input: { name: string }) =>
      Promise.resolve({ created: true, template: { id, name: input.name } }),
    ),
  };
  const repository = {
    findOwnProposal: jest.fn().mockResolvedValue({
      id: PROPOSAL,
      name: 'Haut du corps, format court',
      estimatedMinutes: 25,
      items: [set('s2', 0, 1, 'couche'), set('s1', 0, 0, 'couche'), set('s3', 1, 0, 'tirage')],
    }),
  };
  const logger = { info: jest.fn(), warn: jest.fn() };
  const creator = new CoachWorkoutCreator(
    templates as unknown as WorkoutTemplatesService,
    repository as unknown as CoachRepository,
    logger as unknown as PinoLogger,
  );
  return { creator, templates, repository };
}

/** « Ok crée-la » : une proposition devient un vrai modèle de séance, une fois. */
describe('CoachWorkoutCreator', () => {
  it('la proposition devient un modèle, SOUS SON IDENTIFIANT, séries regroupées dans l’ordre', async () => {
    const { creator, templates } = build();

    await expect(creator.fromStored(USER, PROPOSAL)).resolves.toEqual({
      ok: true,
      templateId: PROPOSAL,
      name: 'Haut du corps, format court',
    });
    expect(templates.saveTemplate).toHaveBeenCalledWith(USER, PROPOSAL, {
      name: 'Haut du corps, format court',
      estimatedDurationMinutes: 25,
      exercises: [
        {
          id: expect.any(String) as string,
          exerciseId: 'couche',
          sets: [
            expect.objectContaining({ id: 's1', targetReps: 10, restSeconds: 60 }),
            expect.objectContaining({ id: 's2' }),
          ],
        },
        {
          id: expect.any(String) as string,
          exerciseId: 'tirage',
          sets: [expect.objectContaining({ id: 's3' })],
        },
      ],
    });
  });

  it('déjà créée : la même, jamais réécrite (ses retouches restent), jamais une seconde', async () => {
    const { creator, templates } = build({ id: PROPOSAL, name: 'Retouchée' });

    await expect(creator.fromStored(USER, PROPOSAL)).resolves.toEqual({
      ok: true,
      templateId: PROPOSAL,
      name: 'Retouchée',
    });
    expect(templates.saveTemplate).not.toHaveBeenCalled();
  });

  it('une proposition d’autrui ou disparue : une raison métier, rien d’écrit', async () => {
    const { creator, templates, repository } = build();
    repository.findOwnProposal.mockResolvedValue(null);

    await expect(creator.fromStored(USER, PROPOSAL)).resolves.toMatchObject({ ok: false });
    expect(templates.saveTemplate).not.toHaveBeenCalled();
  });

  it('supprimée de ses modèles depuis : on ne la ressuscite pas, on le dit', async () => {
    const { creator, templates } = build();
    templates.saveTemplate.mockRejectedValue(new NotFoundException());

    const created = await creator.fromStored(USER, PROPOSAL);
    expect(created.ok).toBe(false);
    expect(!created.ok && created.reason).toContain('supprimé');
  });
});
