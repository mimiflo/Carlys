import { type PinoLogger } from 'nestjs-pino';
import { type CoachComposition, type CoachTurnOutput } from '../domain/coach-model.port';
import { type CoachRepository } from '../infrastructure/coach.repository';
import { CoachActions } from './coach-actions';
import { type CoachWorkoutCreator } from './coach-workout-creator';

const USER = 'utilisateur-1';

const composition: CoachComposition = {
  candidates: [
    { id: 'squat', name: 'Squat', muscle: 'quadriceps', equipment: [] },
    { id: 'hip', name: 'Hip thrust', muscle: 'fessiers', equipment: [] },
  ],
  minutes: null,
  context: [],
};

const output = (
  text: string,
  proposal: Record<string, unknown> | null = null,
): CoachTurnOutput => ({
  text,
  proposal,
  usage: { inputTokens: 1, outputTokens: 1, cacheReadTokens: 0 },
  refused: false,
});

function build() {
  const repository = {
    // Le catalogue connaît ces deux exercices : la proposition se valide.
    catalogueNames: jest.fn().mockResolvedValue(
      new Map([
        ['squat', 'Squat'],
        ['hip', 'Hip thrust'],
      ]),
    ),
    findOwnProposal: jest.fn(),
  };
  const creator = {
    save: jest.fn((_user: string, id: string, workout: { name: string }) =>
      Promise.resolve({ ok: true, templateId: id, name: workout.name }),
    ),
  };
  const logger = { info: jest.fn(), warn: jest.fn() };
  const actions = new CoachActions(
    repository as unknown as CoachRepository,
    creator as unknown as CoachWorkoutCreator,
    logger as unknown as PinoLogger,
  );
  return { actions, creator };
}

const asked = {
  kind: 'WORKOUT_PROPOSAL_REQUIRED',
  request: 'Séance jambes',
  minutes: null,
} as const;

/**
 * Le contrat d'un tour d'action (ADR 0014) : « Je te conseille 3 séries de
 * pompes… » n'est PAS une réponse valide à une demande de séance.
 */
describe('CoachActions.settle', () => {
  it('une séance exigée, rendue en texte seul : le serveur la compose, la carte arrive', async () => {
    const { actions } = build();

    const settled = await actions.settle(
      USER,
      asked,
      output('Je te conseille 3 séries de squats.'),
      composition,
      { messageId: 'message-1' },
    );

    expect(settled.proposal?.items.map((item) => item.exerciseId)).toContain('squat');
    expect(settled.proposal?.id).toEqual(expect.any(String));
    // Le message dit la séance de la carte, pas une autre.
    expect(settled.text).toContain('squat');
    expect(settled.createdTemplateId).toBeNull();
  });

  it('rien de faisable à proposer : la raison métier, jamais un texte qui fait comme si', async () => {
    const { actions } = build();

    const settled = await actions.settle(USER, asked, output('Voici ta séance !'), null, {
      messageId: 'message-2',
    });

    expect(settled.proposal).toBeNull();
    expect(settled.text).toContain('de quoi composer');
  });

  it('une conversation ordinaire : rien d’imposé', async () => {
    const { actions } = build();

    await expect(
      actions.settle(USER, { kind: 'KNOWLEDGE' }, output('Le squat sollicite…'), null, {
        messageId: 'message-3',
      }),
    ).resolves.toEqual({ text: 'Le squat sollicite…', proposal: null, createdTemplateId: null });
  });

  it('« Crée-moi une séance jambes » : composée, PUIS enregistrée sous l’identifiant de sa carte', async () => {
    const { actions, creator } = build();
    const steps: [string, boolean][] = [];

    const settled = await actions.settle(
      USER,
      {
        kind: 'WORKOUT_CREATION_REQUIRED',
        proposalId: null,
        request: 'Crée-moi une séance jambes',
        minutes: null,
      },
      output('Voilà.'),
      composition,
      { messageId: 'message-4', onStep: (step, done) => steps.push([step, done]) },
    );

    expect(creator.save).toHaveBeenCalledWith(
      USER,
      settled.proposal?.id,
      expect.objectContaining({ name: 'Séance du coach' }),
    );
    expect(settled.createdTemplateId).toBe(settled.proposal?.id);
    // Dit APRÈS l'écriture en base, jamais avant.
    expect(settled.text).toContain('C’est enregistré');
    // « Je prépare ta séance » se coche une fois composée, puis l'enregistrement.
    expect(steps).toEqual([
      ['compose_session', true],
      ['create_workout', false],
      ['create_workout', true],
    ]);
  });

  it('rejoué après une panne, le même message retrouve la même carte : jamais deux séances', async () => {
    const { actions } = build();
    const intent = {
      kind: 'WORKOUT_CREATION_REQUIRED',
      proposalId: null,
      request: 'Crée-moi une séance jambes',
      minutes: null,
    } as const;

    const first = await actions.settle(USER, intent, output('Voilà.'), composition, {
      messageId: 'm',
    });
    const again = await actions.settle(USER, intent, output('Voilà.'), composition, {
      messageId: 'm',
    });

    expect(again.proposal?.id).toBe(first.proposal?.id);
    expect(first.proposal?.id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
  });

  it('création refusée par la base : sa raison, pas « c’est enregistré »', async () => {
    const { actions, creator } = build();
    creator.save.mockResolvedValue({
      ok: false,
      reason: 'Tu avais supprimé cette séance.',
    } as never);

    const settled = await actions.settle(
      USER,
      { kind: 'WORKOUT_CREATION_REQUIRED', proposalId: null, request: 'Crée-la', minutes: null },
      output('Voilà.'),
      composition,
      { messageId: 'message-5' },
    );

    expect(settled.createdTemplateId).toBeNull();
    expect(settled.text).toContain('Tu avais supprimé cette séance.');
    expect(settled.text).not.toContain('C’est enregistré');
  });
});
