import {
  type CoachModelPort,
  CoachProviderUnavailableException,
  type CoachTurnInput,
  type CoachTurnOutput,
} from '../domain/coach-model.port';
import { FallbackCoachModel } from './fallback-coach-model';

const INPUT: CoachTurnInput = {
  system: 's',
  tools: [],
  history: [{ role: 'user', content: 'Salut' }],
  runTools: () => Promise.resolve([]),
};
const OUTPUT: CoachTurnOutput = {
  text: 'Depuis le cloud.',
  proposal: null,
  usage: { inputTokens: 5, outputTokens: 3, cacheReadTokens: 0 },
  refused: false,
};
const down = (inputTokens: number) =>
  new CoachProviderUnavailableException('Coach : injoignable.', {
    inputTokens,
    outputTokens: 0,
    cacheReadTokens: 0,
  });
const model = (reply: CoachModelPort['reply']): CoachModelPort => ({ reply });

describe('FallbackCoachModel', () => {
  it('aucun worker n’a répondu : le cloud prend le tour', async () => {
    const cloud = jest.fn().mockResolvedValue(OUTPUT);
    const fallback = new FallbackCoachModel(
      model(() => Promise.reject(down(0))),
      model(cloud),
    );

    await expect(fallback.reply(INPUT)).resolves.toBe(OUTPUT);
    expect(cloud).toHaveBeenCalledTimes(1);
  });

  it('une réponse déjà commencée ne recommence pas ailleurs', async () => {
    const cloud = jest.fn();
    const fallback = new FallbackCoachModel(
      model(() => Promise.reject(down(1))),
      model(cloud),
    );

    await expect(fallback.reply(INPUT)).rejects.toBeInstanceOf(CoachProviderUnavailableException);
    expect(cloud).not.toHaveBeenCalled();
  });

  it('une annulation reste une annulation', async () => {
    const cloud = jest.fn();
    const controller = new AbortController();
    controller.abort();
    const fallback = new FallbackCoachModel(
      model(() => Promise.reject(down(0))),
      model(cloud),
    );

    await expect(fallback.reply({ ...INPUT, signal: controller.signal })).rejects.toThrow();
    expect(cloud).not.toHaveBeenCalled();
  });

  it('un travail « local seulement » (résumé de mémoire) ne part jamais dans le cloud', async () => {
    const cloud = jest.fn();
    const fallback = new FallbackCoachModel(
      model(() => Promise.reject(down(0))),
      model(cloud),
    );

    await expect(fallback.reply({ ...INPUT, localOnly: true })).rejects.toThrow();
    expect(cloud).not.toHaveBeenCalled();
  });
});
