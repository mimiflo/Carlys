import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { COACH_GAVE_UP_TEXT, type CoachTurnOutput } from '../domain/coach-model.port';
import { type RedisService } from '../../../infrastructure/cache/redis.service';
import { type CoachRepository } from '../infrastructure/coach.repository';
import { type CoachGateway } from './coach-gateway';
import { CoachMemory, memoryKeep } from './coach-memory';

/** Fenêtre de 12 : le résumé garde les 6 derniers, et attend d'en avoir 13 non résumés. */
const WINDOW = 12;
const MEMORY_BATCH_MIN = WINDOW - memoryKeep(WINDOW) + 1;

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
  pending = MEMORY_BATCH_MIN + 1,
  reply: CoachTurnOutput | null = output('Nouveau résumé.'),
  window = WINDOW,
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
    { coachGateway: { historyMessages: window } } as unknown as AppConfigService,
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

    expect(repository.memoryBacklog).toHaveBeenCalledWith('c', 6, expect.any(Number));
    expect(gateway.background).toHaveBeenCalledTimes(1);
    expect(repository.saveSummary).toHaveBeenCalledWith(
      'c',
      'Nouveau résumé.',
      at(MEMORY_BATCH_MIN),
    );
  });

  it('ne coupe jamais entre une question et sa réponse', async () => {
    // Fenêtre de 10 : le résumé garde les 5 derniers, et le 5e en partant de
    // la fin est une réponse ; le lot se termine donc sur une QUESTION. Fondue
    // seule, sa réponse ne serait ni dans le résumé ni dans l'historique,
    // qui doit s'ouvrir sur une question et l'écarterait.
    const { memory, repository } = setup(7, output('Nouveau résumé.'), 10);

    await expect(memory.refresh('c')).resolves.toBe(true);

    expect(repository.memoryBacklog).toHaveBeenCalledWith('c', 5, expect.any(Number));
    // m6 (question) reste hors du résumé, avec sa réponse : jusqu'à m5.
    expect(repository.saveSummary).toHaveBeenCalledWith('c', 'Nouveau résumé.', at(5));
  });

  it('par paliers : il garde la moitié récente de la fenêtre, et rien tant qu’elle n’est pas pleine', () => {
    expect(memoryKeep(20)).toBe(10);
    expect(memoryKeep(12)).toBe(6);
    expect(memoryKeep(1)).toBe(1);
    expect(MEMORY_BATCH_MIN).toBe(7);
  });

  it('fenêtre pas encore dépassée : aucun appel au modèle', async () => {
    const { memory, gateway } = setup(MEMORY_BATCH_MIN - 1);
    await expect(memory.refresh('c')).resolves.toBe(false);
    expect(gateway.background).not.toHaveBeenCalled();
  });

  it('file occupée (rien lancé) : on réessaiera au prochain tour', async () => {
    const { memory, repository } = setup(MEMORY_BATCH_MIN + 1, null);
    await expect(memory.refresh('c')).resolves.toBe(false);
    expect(repository.saveSummary).not.toHaveBeenCalled();
  });

  it('un modèle qui abandonne n’écrase jamais la mémoire, et la conversation est laissée en paix', async () => {
    const { memory, repository, gateway } = setup(MEMORY_BATCH_MIN + 1, output(COACH_GAVE_UP_TEXT));
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
