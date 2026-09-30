import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { COACH_GAVE_UP_TEXT, type CoachTurnOutput } from '../domain/coach-model.port';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { type CoachRepository } from '../infrastructure/coach.repository';
import { type CoachGateway } from './coach-gateway';
import { CoachMemory, MEMORY_BATCH_MIN } from './coach-memory';

const at = (minute: number) => new Date(2026, 8, 1, 10, minute);
const backlog = (count: number) => ({
  summary: 'Objectif : force.',
  messages: Array.from({ length: count }, (_, i) => ({
    role: i % 2 === 0 ? ('USER' as const) : ('ASSISTANT' as const),
    content: `m${i}`,
    createdAt: at(i),
  })),
});
const output = (text: string): CoachTurnOutput => ({
  text,
  proposal: null,
  usage: { inputTokens: 1, outputTokens: 1, cacheReadTokens: 0 },
  refused: false,
});

function setup(
  pending = MEMORY_BATCH_MIN,
  reply: CoachTurnOutput | null = output('Nouveau résumé.'),
) {
  const repository = {
    memoryBacklog: jest.fn().mockResolvedValue(backlog(pending)),
    saveSummary: jest.fn().mockResolvedValue(undefined),
  };
  const gateway = { background: jest.fn().mockResolvedValue(reply) };
  const paused = new Set<string>();
  const redis = {
    getClient: () => ({
      exists: (key: string) => Promise.resolve(paused.has(key) ? 1 : 0),
      set: (key: string) => {
        paused.add(key);
        return Promise.resolve('OK');
      },
    }),
  };
  const memory = new CoachMemory(
    repository as unknown as CoachRepository,
    gateway as unknown as CoachGateway,
    { coachGateway: { historyMessages: 12 } } as unknown as AppConfigService,
    redis as unknown as RedisService,
    { warn: jest.fn() } as unknown as PinoLogger,
  );
  return { memory, repository, gateway, paused };
}

/** La mémoire des vieux messages : résumée quand ça vaut un appel, jamais inventée. */
describe('CoachMemory', () => {
  it('assez de messages sortis de la fenêtre : résumés, jusqu’au dernier fondu', async () => {
    const { memory, repository, gateway } = setup();

    await expect(memory.refresh('c')).resolves.toBe(true);

    expect(repository.memoryBacklog).toHaveBeenCalledWith('c', 12, expect.any(Number));
    expect(gateway.background).toHaveBeenCalledTimes(1);
    expect(repository.saveSummary).toHaveBeenCalledWith(
      'c',
      'Nouveau résumé.',
      at(MEMORY_BATCH_MIN - 1),
    );
  });

  it('trop peu de messages : aucun appel au modèle', async () => {
    const { memory, gateway } = setup(MEMORY_BATCH_MIN - 1);
    await expect(memory.refresh('c')).resolves.toBe(false);
    expect(gateway.background).not.toHaveBeenCalled();
  });

  it('file occupée (rien lancé) : on réessaiera au prochain tour', async () => {
    const { memory, repository } = setup(MEMORY_BATCH_MIN, null);
    await expect(memory.refresh('c')).resolves.toBe(false);
    expect(repository.saveSummary).not.toHaveBeenCalled();
  });

  it('un modèle qui abandonne n’écrase jamais la mémoire, et la conversation est laissée en paix', async () => {
    const { memory, repository, gateway } = setup(MEMORY_BATCH_MIN, output(COACH_GAVE_UP_TEXT));
    await expect(memory.refresh('c')).rejects.toThrow();
    expect(repository.saveSummary).not.toHaveBeenCalled();

    // Pas de nouvel essai à chaque tour : dix minutes de pause.
    await expect(memory.refresh('c')).resolves.toBe(false);
    expect(gateway.background).toHaveBeenCalledTimes(1);
  });

  it('un résumé court, borné dans le temps : jamais un créneau tenu sans fin', async () => {
    const { memory, gateway } = setup();
    await memory.refresh('c');
    const [input, timeoutMs] = gateway.background.mock.calls[0] as [
      { maxOutputTokens: number },
      number,
    ];
    expect(input.maxOutputTokens).toBeLessThanOrEqual(300);
    expect(timeoutMs).toBeLessThanOrEqual(120_000);
  });
});
