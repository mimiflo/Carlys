import { TrainingGoal } from '@prisma/client';
import { collectProgramProposal } from './coach.proposals';
import { PROPOSE_PROGRAM_TOOL } from './coach.tool-definitions';

/**
 * `propose_program` intercepté pendant le tour : le modèle reçoit une
 * réponse à CHAQUE appel, les autres outils passent intacts, et seule une
 * proposition valide est gardée.
 */
describe('collectProgramProposal', () => {
  const lire = { id: 'c1', name: 'get_training_profile', input: {} };
  const programme = (input: Record<string, unknown>, id = 'c2') => ({
    id,
    name: PROPOSE_PROGRAM_TOOL,
    input,
  });
  const valide = { goal: 'STRENGTH', weeklySessions: 3, sessionMinutes: 45 };

  it('laisse passer les autres outils, et garde la proposition valide', async () => {
    const run = jest.fn().mockResolvedValue([{ id: 'c1', content: '{}' }]);
    const collector = collectProgramProposal(run);

    const results = await collector.runTools([lire, programme(valide)]);

    expect(run).toHaveBeenCalledWith([lire]);
    expect(results.map((result) => result.id)).toEqual(['c1', 'c2']);
    expect(results[1]?.isError).toBeUndefined();
    expect(collector.proposal()).toEqual({
      goal: TrainingGoal.STRENGTH,
      weeklySessions: 3,
      sessionMinutes: 45,
    });
  });

  it('renvoie au modèle le motif d’un refus, sans rien garder', async () => {
    const collector = collectProgramProposal(jest.fn().mockResolvedValue([]));

    const [result] = await collector.runTools([programme({ ...valide, weeklySessions: 12 })]);

    expect(result?.isError).toBe(true);
    expect(result?.content).toContain('weeklySessions');
    expect(collector.proposal()).toBeNull();
  });

  it('une proposition valide survit à un appel invalide qui la suit', async () => {
    const collector = collectProgramProposal(jest.fn().mockResolvedValue([]));

    await collector.runTools([programme(valide)]);
    await collector.runTools([programme({ ...valide, sessionMinutes: 5 }, 'c3')]);

    expect(collector.proposal()?.sessionMinutes).toBe(45);
  });

  it('un refus corrigé dans le même tour : la correction est gardée', async () => {
    const collector = collectProgramProposal(jest.fn().mockResolvedValue([]));

    await collector.runTools([programme({ ...valide, goal: 'YOGA' })]);
    await collector.runTools([programme({ ...valide, weeklySessions: 4 }, 'c3')]);

    expect(collector.proposal()?.weeklySessions).toBe(4);
  });
});
