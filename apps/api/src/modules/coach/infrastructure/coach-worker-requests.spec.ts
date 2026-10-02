import { type AppConfigService } from '../../../config/app-config.service';
import { CoachWorkerPool } from './coach-worker-pool';
import { CoachWorkerRequests } from './coach-worker-requests';
import { GenerationFailure } from './generation-end';

const IDLE_MS = 40;
const chunk = (content: string) =>
  new TextEncoder().encode(
    `data: ${JSON.stringify({ choices: [{ delta: { content }, finish_reason: null }] })}\n\n`,
  );
const DONE = new TextEncoder().encode(
  'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
);

/** Un flux qui, comme le vrai, s'interrompt quand sa requête est annulée. */
function body(signal: AbortSignal, write: (c: ReadableStreamDefaultController) => void) {
  return new Response(
    new ReadableStream({
      start(controller) {
        signal.addEventListener('abort', () => controller.error(signal.reason));
        write(controller);
      },
    }),
  );
}

function setup(respond: (signal: AbortSignal) => Response) {
  const pool = new CoachWorkerPool(['http://ollama:11434/v1'], 30_000);
  const requests = new CoachWorkerRequests(
    {
      coachProvider: { model: 'qwen3' },
      coachGateway: { streamIdleTimeoutMs: IDLE_MS },
    } as unknown as AppConfigService,
    pool,
  );
  jest
    .spyOn(global, 'fetch')
    .mockImplementation((_url, init) => Promise.resolve(respond(init?.signal as AbortSignal)));
  return { pool, requests };
}

/**
 * L'échéance du tour est un plafond ; un worker en panne se mesure au SILENCE
 * de son flux, une fois commencé.
 */
describe('CoachWorkerRequests — le délai d’inactivité du flux', () => {
  afterEach(() => jest.restoreAllMocks());

  it('un flux commencé puis muet : TIMEOUT, et le worker est mis de côté', async () => {
    const { pool, requests } = setup((signal) =>
      body(signal, (c) => c.enqueue(chunk('Le squat '))),
    );
    const seen: string[] = [];

    const failure = await requests
      .complete({ messages: [] }, new AbortController().signal, (d) => seen.push(d), 64)
      .catch((error: unknown) => error);

    expect(failure).toBeInstanceOf(GenerationFailure);
    expect(failure).toMatchObject({ end: 'TIMEOUT' });
    expect(seen).toEqual(['Le squat ']);
    expect(pool.status()[0]).toMatchObject({ healthy: false, active: 0 });
  });

  it('avant le premier octet, rien ne compte que l’échéance : relire un long contexte prend du temps', async () => {
    const { pool, requests } = setup((signal) =>
      body(signal, (c) => {
        setTimeout(() => {
          c.enqueue(chunk('Prêt.'));
          c.enqueue(DONE);
          c.close();
        }, IDLE_MS * 3);
      }),
    );

    const { completion } = await requests.complete(
      { messages: [] },
      new AbortController().signal,
      () => undefined,
      64,
    );

    expect(completion.choices?.[0]?.message?.content).toBe('Prêt.');
    expect(pool.status()[0]).toMatchObject({ healthy: true, active: 0 });
  });

  it('un flux qui parle régulièrement n’est jamais coupé', async () => {
    const { requests } = setup((signal) =>
      body(signal, (c) => {
        let sent = 0;
        const tick = setInterval(() => {
          c.enqueue(chunk(`mot${sent} `));
          if (++sent === 5) {
            clearInterval(tick);
            c.enqueue(DONE);
            c.close();
          }
        }, IDLE_MS / 2);
      }),
    );

    const { completion } = await requests.complete(
      { messages: [] },
      new AbortController().signal,
      () => undefined,
      64,
    );
    expect(completion.choices?.[0]?.finish_reason).toBe('stop');
  });

  it('une connexion coupée en plein flux : STREAM_ERROR', async () => {
    const { requests } = setup((signal) =>
      body(signal, (c) => {
        c.enqueue(chunk('Le squat '));
        setTimeout(() => c.error(new TypeError('terminated')), 5);
      }),
    );

    await expect(
      requests.complete({ messages: [] }, new AbortController().signal, () => undefined, 64),
    ).rejects.toMatchObject({ end: 'STREAM_ERROR' });
  });
});
