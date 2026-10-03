import { BadRequestException, HttpException, HttpStatus } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import {
  CoachProviderUnavailableException,
  type CoachTurnInput,
  type CoachTurnOutput,
} from '../domain/coach-model.port';
import { type CoachGate, type GatePoll } from '../infrastructure/coach-gate';
import { type CoachGenerationRepository } from '../infrastructure/coach-generation.repository';
import { type CoachMetrics } from '../infrastructure/coach-metrics';
import { CoachAdmissions } from './coach-admissions';
import { CoachGateway } from './coach-gateway';
import { type CoachQuota } from './coach.quota';

// Les tours de garde de la file sont instantanés ici.
jest.mock('node:timers/promises', () => ({ setTimeout: jest.fn(() => Promise.resolve()) }));

const OUTPUT: CoachTurnOutput = {
  text: 'Salut.',
  proposal: null,
  usage: { inputTokens: 40, outputTokens: 12, cacheReadTokens: 0 },
  refused: false,
  worker: 'ollama:11434',
};
const INPUT: CoachTurnInput = {
  system: 's',
  tools: [],
  history: [{ role: 'user', content: 'Salut' }],
  runTools: () => Promise.resolve([]),
};

function setup(settings: Partial<{ queueTimeoutMs: number; maxMessageChars: number }> = {}) {
  const gate = {
    enter: jest.fn().mockResolvedValue('ok'),
    poll: jest.fn<Promise<GatePoll>, [string]>().mockResolvedValue({ acquired: true }),
    leave: jest.fn().mockResolvedValue(undefined),
    renew: jest.fn().mockResolvedValue(true),
    snapshot: jest.fn().mockResolvedValue({ active: 0, queued: 0 }),
    tryBackground: jest.fn().mockResolvedValue(true),
  };
  const generations = {
    queued: jest.fn().mockResolvedValue(undefined),
    started: jest.fn().mockResolvedValue(undefined),
    streaming: jest.fn().mockResolvedValue(undefined),
    ended: jest.fn().mockResolvedValue(undefined),
  };
  const quota = { withinRate: jest.fn().mockResolvedValue(true) };
  const model = {
    reply: jest.fn<Promise<CoachTurnOutput>, [CoachTurnInput]>().mockResolvedValue(OUTPUT),
  };
  const counters = new Map<string, { inc: jest.Mock; dec: jest.Mock; observe: jest.Mock }>();
  const metrics = new Proxy(
    {},
    {
      get: (_target, name: string) => {
        if (!counters.has(name))
          counters.set(name, { inc: jest.fn(), dec: jest.fn(), observe: jest.fn() });
        return counters.get(name);
      },
    },
  );
  const config = {
    coachProvider: { model: 'qwen3' },
    coachGateway: {
      maxMessageChars: 2000,
      queueTimeoutMs: 120_000,
      requestTimeoutMs: 180_000,
      ...settings,
    },
  } as unknown as AppConfigService;
  const gateway = new CoachGateway(
    gate as unknown as CoachGate,
    generations as unknown as CoachGenerationRepository,
    metrics as unknown as CoachMetrics,
    config,
    model,
    { warn: jest.fn(), info: jest.fn() } as unknown as PinoLogger,
  );
  const admissions = new CoachAdmissions(
    gate as unknown as CoachGate,
    quota as unknown as CoachQuota,
    metrics as unknown as CoachMetrics,
    config,
  );
  return { gateway, admissions, gate, generations, quota, model, counters };
}

describe('CoachGateway — admission : refuser tôt, sans rien consommer', () => {
  it('message trop long : 400', async () => {
    const { admissions, gate } = setup({ maxMessageChars: 10 });
    await expect(admissions.admit('u', 'c', 'm', 'x'.repeat(11))).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(gate.enter).not.toHaveBeenCalled();
  });

  it('trop de messages dans la minute : 429, identité Carlys (pas l’IP)', async () => {
    const { admissions, quota } = setup();
    quota.withinRate.mockResolvedValue(false);
    const error = (await admissions
      .admit('u', 'c', 'm', 'Salut')
      .catch((e: unknown) => e)) as HttpException;
    expect(error.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
    expect(quota.withinRate).toHaveBeenCalledWith('u');
  });

  it('déjà une réponse en cours pour cette personne : 429', async () => {
    const { admissions, gate } = setup();
    gate.enter.mockResolvedValue('user_busy');
    const error = (await admissions
      .admit('u', 'c', 'm', 'Salut')
      .catch((e: unknown) => e)) as HttpException;
    expect(error.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
  });

  it('file pleine : 503 SERVICE_BUSY, un message écrit pour la personne', async () => {
    const { admissions, gate, counters } = setup();
    gate.enter.mockResolvedValue('busy');
    const error = (await admissions
      .admit('u', 'c', 'm', 'Salut')
      .catch((e: unknown) => e)) as UserFacingUnavailableException;
    expect(error).toBeInstanceOf(UserFacingUnavailableException);
    expect(error.code).toBe('SERVICE_BUSY');
    expect(counters.get('requests')?.inc).toHaveBeenCalledWith({ outcome: 'busy' });
  });

  it('admise : la place se rend par `release`', async () => {
    const { admissions, gate } = setup();
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');
    await admission.release();
    expect(gate.leave).toHaveBeenCalledWith(admission.requestId, 'u');
  });
});

describe('CoachGateway — génération', () => {
  it('attend son tour en le disant, puis génère et mesure (COMPLETED, worker, jetons)', async () => {
    const { gateway, admissions, gate, generations, model } = setup();
    gate.poll
      .mockResolvedValueOnce({ acquired: false, ahead: 2 })
      .mockResolvedValueOnce({ acquired: false, ahead: 2 })
      .mockResolvedValueOnce({ acquired: false, ahead: 1 })
      .mockResolvedValueOnce({ acquired: true });
    const queued: number[] = [];
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');

    const started = jest.fn();
    await expect(
      gateway.generate(
        admission,
        { stream: true, onQueued: (ahead) => queued.push(ahead), onStarted: started },
        () => Promise.resolve(INPUT),
      ),
    ).resolves.toBe(OUTPUT);
    expect(started).toHaveBeenCalledTimes(1);

    expect(queued).toEqual([2, 1]);
    expect(model.reply).toHaveBeenCalledTimes(1);
    expect(generations.queued).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 'u', conversationId: 'c', messageId: 'm' }),
    );
    expect(generations.started).toHaveBeenCalled();
    expect(generations.ended).toHaveBeenCalledWith(
      admission.requestId,
      expect.any(Date),
      expect.objectContaining({ status: 'COMPLETED', worker: 'ollama:11434', outputTokens: 12 }),
    );
  });

  it('le premier morceau de texte date le premier mot (STREAMING)', async () => {
    const { gateway, admissions, generations, model } = setup();
    const seen: string[] = [];
    model.reply.mockImplementation((input) => {
      input.onText?.('Sal');
      input.onText?.('ut.');
      return Promise.resolve(OUTPUT);
    });
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');

    await gateway.generate(admission, { stream: true }, () =>
      Promise.resolve({ ...INPUT, onText: (t: string) => seen.push(t) }),
    );

    expect(seen).toEqual(['Sal', 'ut.']);
    expect(generations.streaming).toHaveBeenCalledTimes(1);
  });

  it('file trop longue : « très sollicité », sans appeler le modèle', async () => {
    const { gateway, admissions, gate, generations, model } = setup({ queueTimeoutMs: 1_000 });
    gate.poll.mockResolvedValue({ acquired: false, ahead: 3 });
    const now = jest.spyOn(Date, 'now');
    // Arrivée et échéance calculées à t = 0, puis l'horloge a filé.
    now.mockReturnValueOnce(0).mockReturnValueOnce(0).mockReturnValue(5_000);
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');

    const prepare = jest.fn(() => Promise.resolve(INPUT));
    await expect(gateway.generate(admission, { stream: true }, prepare)).rejects.toBeInstanceOf(
      UserFacingUnavailableException,
    );
    now.mockRestore();
    expect(model.reply).not.toHaveBeenCalled();
    // Rien de décompté ni d'écrit : la file a refusé, la personne n'a rien payé.
    expect(prepare).not.toHaveBeenCalled();
    expect(generations.ended).toHaveBeenCalledWith(
      admission.requestId,
      expect.any(Date),
      expect.objectContaining({ status: 'FAILED', errorCode: 'queue_timeout' }),
    );
  });

  it('annulée dans la file : CANCELLED, et une erreur « rien consommé » (le message est rendu)', async () => {
    const { gateway, admissions, gate, generations, model } = setup();
    gate.poll.mockResolvedValue({ acquired: false, ahead: 1 });
    const controller = new AbortController();
    controller.abort();
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');

    const error = (await gateway
      .generate(admission, { stream: true, signal: controller.signal }, () =>
        Promise.resolve(INPUT),
      )
      .catch((e: unknown) => e)) as CoachProviderUnavailableException;

    expect(error).toBeInstanceOf(CoachProviderUnavailableException);
    expect(error.usage.inputTokens).toBe(0);
    expect(model.reply).not.toHaveBeenCalled();
    expect(generations.ended).toHaveBeenCalledWith(
      admission.requestId,
      expect.any(Date),
      expect.objectContaining({ status: 'CANCELLED' }),
    );
  });

  it('panne du fournisseur : FAILED, raison courte, l’erreur repart telle quelle', async () => {
    const { gateway, admissions, generations, model } = setup();
    const down = new CoachProviderUnavailableException(
      'Coach : fournisseur injoignable (TimeoutError).',
      {
        inputTokens: 0,
        outputTokens: 0,
        cacheReadTokens: 0,
      },
      'TIMEOUT',
    );
    model.reply.mockRejectedValue(down);
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');

    await expect(
      gateway.generate(admission, { stream: true }, () => Promise.resolve(INPUT)),
    ).rejects.toBe(down);
    expect(generations.ended).toHaveBeenCalledWith(
      admission.requestId,
      expect.any(Date),
      expect.objectContaining({ status: 'FAILED', errorCode: 'timeout' }),
    );
  });

  it('une mesure qui échoue en base ne fait jamais échouer la réponse', async () => {
    const { gateway, admissions, generations } = setup();
    generations.queued.mockRejectedValue(new Error('base indisponible'));
    generations.ended.mockRejectedValue(new Error('base indisponible'));
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');

    await expect(
      gateway.generate(admission, { stream: true }, () => Promise.resolve(INPUT)),
    ).resolves.toBe(OUTPUT);
  });

  it('le quota refusé APRÈS la file : FAILED « quota », sans appeler le modèle', async () => {
    const { gateway, admissions, generations, model } = setup();
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');
    const refusal = new HttpException('Plafond du jour', HttpStatus.TOO_MANY_REQUESTS);

    await expect(
      gateway.generate(admission, { stream: true }, () => Promise.reject(refusal)),
    ).rejects.toBe(refusal);
    expect(model.reply).not.toHaveBeenCalled();
    expect(generations.ended).toHaveBeenCalledWith(
      admission.requestId,
      expect.any(Date),
      expect.objectContaining({ status: 'FAILED', errorCode: 'quota' }),
    );
  });

  it('sans flux (anciennes versions), l’attente reste courte : le tour doit tenir sous nginx', async () => {
    const { gateway, admissions, gate } = setup();
    gate.poll.mockResolvedValue({ acquired: false, ahead: 1 });
    const now = jest.spyOn(Date, 'now');
    // 6 s d'attente : au-delà des 5 s permises sans flux, bien en deçà des 120 s en flux.
    now.mockReturnValueOnce(0).mockReturnValueOnce(0).mockReturnValue(6_000);
    const admission = await admissions.admit('u', 'c', 'm', 'Salut');

    await expect(
      gateway.generate(admission, { stream: false }, () => Promise.resolve(INPUT)),
    ).rejects.toBeInstanceOf(UserFacingUnavailableException);
    now.mockRestore();
  });
});

describe('CoachGateway — travail de fond', () => {
  it('personne n’attend : lancé avec son échéance, puis la place est rendue', async () => {
    const { gateway, gate, model } = setup();
    await expect(gateway.background(INPUT, 60_000)).resolves.toBe(OUTPUT);
    expect(model.reply).toHaveBeenCalledWith(expect.objectContaining({ timeoutMs: 60_000 }));
    expect(gate.leave).toHaveBeenCalledTimes(1);
  });

  it('quelqu’un attend ou tout est pris : rien n’est lancé', async () => {
    const { gateway, gate, model } = setup();
    gate.tryBackground.mockResolvedValue(false);
    await expect(gateway.background(INPUT, 60_000)).resolves.toBeNull();
    expect(model.reply).not.toHaveBeenCalled();
  });

  it('une personne arrive dans la file : le fond CÈDE sa place', async () => {
    jest.useFakeTimers();
    const { gateway, gate, model } = setup();
    gate.snapshot.mockResolvedValue({ active: 1, queued: 1 });
    model.reply.mockImplementation(
      (input) =>
        new Promise((_resolve, reject) =>
          input.signal?.addEventListener('abort', () => reject(new Error('abandon'))),
        ),
    );

    const pending = gateway.background(INPUT, 60_000);
    await jest.advanceTimersByTimeAsync(2_000);

    await expect(pending).resolves.toBeNull();
    expect(gate.leave).toHaveBeenCalledTimes(1);
    jest.useRealTimers();
  });
});
