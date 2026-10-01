import { ServiceUnavailableException } from '@nestjs/common';
import { setTimeout as wait } from 'node:timers/promises';
import { type AppConfigService } from '../../../config/app-config.service';
import {
  COACH_GAVE_UP_TEXT,
  COACH_MAX_TOOL_ROUNDS,
  COACH_TURN_DEADLINE_MS,
  CoachProviderUnavailableException,
  type CoachToolCall,
  type CoachTurnInput,
} from '../domain/coach-model.port';
import { CoachWorkerPool } from './coach-worker-pool';
import { OpenAiCompatibleCoachClient } from './openai-compatible.client';

/** L'échéance d'un tour en flux, telle que la passerelle la règle. */
const STREAM_TIMEOUT_MS = 180_000;

// Les pauses entre deux tentatives sont instantanées ici : on vérifie
// qu'elles ont lieu, sans attendre de vraies secondes.
jest.mock('node:timers/promises', () => ({ setTimeout: jest.fn(() => Promise.resolve()) }));

const MISTRAL = {
  baseUrl: 'https://api.mistral.ai/v1/',
  apiKey: 'cle-mistral-factice',
  model: 'mistral-small-latest',
};

function client(provider: { baseUrl?: string; apiKey?: string; model?: string } = MISTRAL) {
  return new OpenAiCompatibleCoachClient(
    {
      coachProvider: provider,
      coachGateway: { requestTimeoutMs: STREAM_TIMEOUT_MS, maxOutputTokens: 2048 },
    } as unknown as AppConfigService,
    new CoachWorkerPool(provider.baseUrl === undefined ? [] : [provider.baseUrl], 30_000),
  );
}

function input(overrides: Partial<CoachTurnInput> = {}): CoachTurnInput {
  return {
    system: 'Tu es le coach.',
    systemPerUser: 'Profil Constructeur.',
    tools: [
      {
        name: 'get_personal_records',
        description: 'Records. Appelle-le avant un chiffre.',
        inputSchema: { type: 'object', properties: {} },
      },
    ],
    history: [{ role: 'user', content: 'Mes records ?' }],
    runTools: (calls: CoachToolCall[]) =>
      Promise.resolve(calls.map((call) => ({ id: call.id, content: '{"records":[]}' }))),
    ...overrides,
  };
}

/** Une réponse Chat Completions, au format que rend Mistral. */
function completion(
  message: Record<string, unknown>,
  finishReason = 'stop',
  usage: Record<string, unknown> = { prompt_tokens: 100, completion_tokens: 20 },
) {
  return {
    ok: true,
    status: 200,
    json: () =>
      Promise.resolve({
        choices: [
          { index: 0, finish_reason: finishReason, message: { role: 'assistant', ...message } },
        ],
        usage,
      }),
  };
}

function failure(
  status: number,
  body = '{"message":"erreur"}',
  headers: Record<string, string> = {},
) {
  return {
    ok: false,
    status,
    headers: new Headers(headers),
    // Rejette, comme `fetch`, sur un corps qui n'est pas du JSON.
    json: jest.fn(() => Promise.resolve().then(() => JSON.parse(body) as unknown)),
    body: { cancel: jest.fn(() => Promise.resolve()) },
  };
}

function toolCall(id: string, name: string, args: string) {
  return { id, type: 'function', function: { name, arguments: args } };
}

function sent(fetchMock: jest.Mock, call = 0) {
  const [url, init] = fetchMock.mock.calls[call] as [string, RequestInit];
  return {
    url,
    init,
    headers: init.headers as Record<string, string>,
    body: JSON.parse(init.body as string) as {
      model: string;
      max_tokens: number;
      messages: Record<string, unknown>[];
      tools: Record<string, unknown>[];
    },
  };
}

describe('OpenAiCompatibleCoachClient', () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
    jest.clearAllMocks();
  });

  describe('la requête', () => {
    it('suit le format Chat Completions : adresse, clé, modèle, système partagé PUIS par utilisateur, outils', async () => {
      const fetchMock = jest.fn().mockResolvedValue(completion({ content: 'Salut.' }));
      global.fetch = fetchMock;

      await client().reply(input());

      const { url, init, headers, body } = sent(fetchMock);
      // La barre finale de l'adresse ne double pas la barre du chemin.
      expect(url).toBe('https://api.mistral.ai/v1/chat/completions');
      expect(init.method).toBe('POST');
      expect(init.signal).toBeInstanceOf(AbortSignal);
      expect(headers['Authorization']).toBe('Bearer cle-mistral-factice');
      expect(body.model).toBe('mistral-small-latest');
      expect(body.max_tokens).toBe(2048);
      expect(body.messages).toEqual([
        { role: 'system', content: 'Tu es le coach.' },
        { role: 'system', content: 'Profil Constructeur.' },
        { role: 'user', content: 'Mes records ?' },
      ]);
      expect(body.tools).toEqual([
        {
          type: 'function',
          function: {
            name: 'get_personal_records',
            description: 'Records. Appelle-le avant un chiffre.',
            parameters: { type: 'object', properties: {} },
          },
        },
      ]);
    });

    it(`UNE échéance de ${COACH_TURN_DEADLINE_MS} ms pour tout le tour : la même à chaque tentative, à chaque tour d’outils et à chaque pause`, async () => {
      // Une échéance neuve par appel laisserait un tour dépasser les 60 s de
      // nginx : 504 muet, et le 503 qui rend le quota n'arriverait jamais.
      const timeout = jest.spyOn(AbortSignal, 'timeout');
      const fetchMock = jest
        .fn()
        .mockResolvedValueOnce(failure(429))
        .mockResolvedValueOnce(
          completion({
            content: null,
            tool_calls: [toolCall('abc123XYZ', 'get_personal_records', '{}')],
          }),
        )
        .mockResolvedValueOnce(completion({ content: 'Fini.' }));
      global.fetch = fetchMock;

      await client().reply(input());

      expect(timeout).toHaveBeenCalledTimes(1);
      expect(timeout).toHaveBeenCalledWith(COACH_TURN_DEADLINE_MS);
      const signal = timeout.mock.results[0]?.value as AbortSignal;
      expect(fetchMock).toHaveBeenCalledTimes(3);
      for (let call = 0; call < 3; call++) {
        expect(sent(fetchMock, call).init.signal).toBe(signal);
      }
      const [, , pause] = (wait as unknown as jest.Mock).mock.calls[0] as [
        number,
        undefined,
        { signal?: AbortSignal } | undefined,
      ];
      expect(pause?.signal).toBe(signal);
      timeout.mockRestore();
    });

    it(`EN FLUX, le tour a ${STREAM_TIMEOUT_MS} ms : sur processeur, relire des séances dépasse à lui seul 50 s`, async () => {
      // nginx ne coupe qu'après 60 s SANS octet ; en flux, le texte et les
      // battements de `sseKeepAlive` l'en empêchent. L'échéance courte ne
      // protège que la route sans flux.
      const timeout = jest.spyOn(AbortSignal, 'timeout');
      global.fetch = jest.fn().mockRejectedValue(new TypeError('fetch failed'));

      await expect(client().reply(input({ onText: jest.fn() }))).rejects.toThrow();

      expect(timeout).toHaveBeenCalledWith(STREAM_TIMEOUT_MS);
      timeout.mockRestore();
    });

    it('sans clé (Ollama interne), aucun en-tête Authorization ; bloc par utilisateur vide, omis', async () => {
      const fetchMock = jest.fn().mockResolvedValue(completion({ content: 'Salut.' }));
      global.fetch = fetchMock;

      await client({ baseUrl: 'http://ollama:11434/v1', model: 'ministral-3:8b' }).reply(
        input({ systemPerUser: '' }),
      );

      const { headers, body } = sent(fetchMock);
      expect(headers).not.toHaveProperty('Authorization');
      expect(body.messages.filter((message) => message['role'] === 'system')).toHaveLength(1);
    });
  });

  describe('la réponse', () => {
    it('un texte simple, et ses jetons (cache absent : 0)', async () => {
      global.fetch = jest
        .fn()
        .mockResolvedValue(completion({ content: '  Ton record : 100 kg.  ' }));

      const output = await client().reply(input());

      expect(output).toEqual({
        text: 'Ton record : 100 kg.',
        proposal: null,
        usage: { inputTokens: 100, outputTokens: 20, cacheReadTokens: 0 },
        refused: false,
        // L'hôte seul : ce qui part en base et aux métriques.
        worker: 'api.mistral.ai',
        model: 'mistral-small-latest',
      });
    });

    it('un contenu en morceaux (modèle qui raisonne) : seul le texte final est gardé', async () => {
      global.fetch = jest.fn().mockResolvedValue(
        completion({
          content: [
            { type: 'thinking', thinking: [{ type: 'text', text: 'Je réfléchis…' }] },
            { type: 'text', text: 'Fais trois séries.' },
          ],
        }),
      );

      const output = await client().reply(input());

      expect(output.text).toBe('Fais trois séries.');
    });

    it('un contenu vide ne donne jamais une bulle vide', async () => {
      global.fetch = jest.fn().mockResolvedValue(completion({ content: '' }));

      await expect(client().reply(input())).resolves.toMatchObject({ text: COACH_GAVE_UP_TEXT });
    });
  });

  describe('la boucle d’outils', () => {
    it('décide sur la PRÉSENCE d’appels, même annoncés « stop », et renvoie chaque résultat par son identifiant', async () => {
      const fetchMock = jest
        .fn()
        .mockResolvedValueOnce(
          completion(
            { content: null, tool_calls: [toolCall('abc123XYZ', 'get_personal_records', '{}')] },
            // Ollama et d'autres rendent « stop » AVEC des appels d'outils.
            'stop',
            {
              prompt_tokens: 100,
              completion_tokens: 10,
              prompt_tokens_details: { cached_tokens: 80 },
            },
          ),
        )
        .mockResolvedValueOnce(completion({ content: 'Aucun record encore.' }));
      global.fetch = fetchMock;
      const runTools = jest.fn((calls: CoachToolCall[]) =>
        Promise.resolve(calls.map((call) => ({ id: call.id, content: '{"records":[]}' }))),
      );

      const output = await client().reply(input({ runTools }));

      expect(runTools).toHaveBeenCalledWith([
        { id: 'abc123XYZ', name: 'get_personal_records', input: {} },
      ]);
      const second = sent(fetchMock, 1).body.messages;
      expect(second.slice(-2)).toEqual([
        {
          role: 'assistant',
          // Chaîne vide plutôt que null : c'est la forme de l'exemple Mistral.
          content: '',
          tool_calls: [toolCall('abc123XYZ', 'get_personal_records', '{}')],
        },
        { role: 'tool', tool_call_id: 'abc123XYZ', content: '{"records":[]}' },
      ]);
      expect(output.text).toBe('Aucun record encore.');
      // Jetons ADDITIONNÉS sur les deux appels.
      expect(output.usage).toEqual({ inputTokens: 200, outputTokens: 30, cacheReadTokens: 80 });
    });

    it('propose_session est RETENUE, jamais exécutée, et acquittée ; arguments illisibles : {} ; erreur d’outil signalée', async () => {
      const seance = { title: 'Jambes 30 min', items: [] };
      const fetchMock = jest
        .fn()
        .mockResolvedValueOnce(
          completion(
            {
              content: 'Je regarde.',
              tool_calls: [
                toolCall('call00001', 'get_personal_records', '{pas du json'),
                toolCall('call00002', 'propose_session', JSON.stringify(seance)),
              ],
            },
            'tool_calls',
          ),
        )
        .mockResolvedValueOnce(completion({ content: 'Voici ta séance.' }));
      global.fetch = fetchMock;
      const runTools = jest.fn((calls: CoachToolCall[]) =>
        Promise.resolve(
          calls.map((call) => ({ id: call.id, content: 'Base indisponible.', isError: true })),
        ),
      );

      const output = await client().reply(input({ runTools }));

      // Seul l'outil de lecture s'exécute, avec des arguments vides.
      expect(runTools).toHaveBeenCalledWith([
        { id: 'call00001', name: 'get_personal_records', input: {} },
      ]);
      expect(output.proposal).toEqual(seance);
      expect(sent(fetchMock, 1).body.messages.slice(-2)).toEqual([
        { role: 'tool', tool_call_id: 'call00001', content: 'Erreur : Base indisponible.' },
        { role: 'tool', tool_call_id: 'call00002', content: 'Proposition reçue.' },
      ]);
    });

    it('la phrase jointe à la proposition survit à un dernier tour vide', async () => {
      // Le prompt exige une phrase avec la proposition : le modèle la dit AVEC
      // l'appel, puis n'a plus rien à ajouter après l'accusé de réception.
      global.fetch = jest
        .fn()
        .mockResolvedValueOnce(
          completion({
            content: 'J’ai retiré le squat, pas de barre.',
            tool_calls: [toolCall('call00001', 'propose_session', '{"name":"Jambes"}')],
          }),
        )
        .mockResolvedValueOnce(completion({ content: '' }));

      await expect(client().reply(input())).resolves.toMatchObject({
        text: 'J’ai retiré le squat, pas de barre.',
        proposal: { name: 'Jambes' },
      });
    });

    it('« Une minute. » sans appel d’outil : relancé UNE fois, la vraie réponse arrive', async () => {
      // Constaté sur Qwen3-4B : l'annonce rendait la main, et la personne
      // attendait une suite qui ne venait jamais.
      const fetchMock = jest
        .fn()
        .mockResolvedValueOnce(completion({ content: 'Je cherche tes records. Une minute.' }))
        .mockResolvedValueOnce(
          completion({
            content: '',
            tool_calls: [toolCall('call00001', 'get_personal_records', '{}')],
          }),
        )
        .mockResolvedValueOnce(completion({ content: 'Ton record au squat : 100 kg.' }))
        .mockResolvedValueOnce(completion({ content: 'Je vérifie encore une fois.' }));
      global.fetch = fetchMock;

      await expect(client().reply(input())).resolves.toMatchObject({
        text: 'Ton record au squat : 100 kg.',
      });
      // La relance suit l'annonce, comme un message de la personne.
      const relance = sent(fetchMock, 1).body.messages.slice(-2);
      expect(relance[0]).toMatchObject({
        role: 'assistant',
        content: 'Je cherche tes records. Une minute.',
      });
      expect(relance[1]?.role).toBe('user');
      expect(String(relance[1]?.content)).toContain('Appelle maintenant');
      expect(fetchMock).toHaveBeenCalledTimes(3);
    });

    it('après une proposition retenue, « Voici la séance : » n’est pas une annonce à relancer', async () => {
      const fetchMock = jest
        .fn()
        .mockResolvedValueOnce(
          completion({
            content: '',
            tool_calls: [toolCall('call00001', 'propose_session', '{"name":"Pecs"}')],
          }),
        )
        .mockResolvedValueOnce(completion({ content: 'Voici la séance que je te propose :' }));
      global.fetch = fetchMock;

      await expect(client().reply(input())).resolves.toMatchObject({
        text: 'Voici la séance que je te propose :',
        proposal: { name: 'Pecs' },
      });
      expect(fetchMock).toHaveBeenCalledTimes(2);
    });

    it('une seule relance par tour : une seconde annonce est rendue telle quelle', async () => {
      global.fetch = jest
        .fn()
        .mockResolvedValueOnce(completion({ content: 'Une minute.' }))
        .mockResolvedValueOnce(completion({ content: 'Je regarde encore, un instant.' }));

      await expect(client().reply(input())).resolves.toMatchObject({
        text: 'Je regarde encore, un instant.',
      });
    });

    it('un appel d’outil sans `function` (passerelle non conforme) : outil inconnu, pas un 500', async () => {
      global.fetch = jest
        .fn()
        .mockResolvedValueOnce(
          completion({ content: null, tool_calls: [{ id: 'bancal001', type: 'function' }] }),
        )
        .mockResolvedValueOnce(completion({ content: 'Je continue sans.' }));
      const runTools = jest.fn((calls: CoachToolCall[]) =>
        Promise.resolve(
          calls.map((call) => ({ id: call.id, content: 'Outil inconnu.', isError: true })),
        ),
      );

      await expect(client().reply(input({ runTools }))).resolves.toMatchObject({
        text: 'Je continue sans.',
      });
      expect(runTools).toHaveBeenCalledWith([{ id: 'bancal001', name: '', input: {} }]);
    });

    it(`au-delà de ${COACH_MAX_TOOL_ROUNDS} tours, on arrête les frais et on le dit`, async () => {
      const fetchMock = jest.fn().mockResolvedValue(
        completion({
          content: null,
          tool_calls: [toolCall('boucle001', 'get_personal_records', '{}')],
        }),
      );
      global.fetch = fetchMock;

      const output = await client().reply(input());

      expect(fetchMock).toHaveBeenCalledTimes(COACH_MAX_TOOL_ROUNDS);
      expect(output).toMatchObject({ text: COACH_GAVE_UP_TEXT, refused: false });
    });
  });

  describe('les pannes : toujours un 503, jamais le 429 du fournisseur', () => {
    it('429 puis 500 : deux nouvelles tentatives espacées, puis la réponse', async () => {
      const fetchMock = jest
        .fn()
        .mockResolvedValueOnce(failure(429))
        .mockResolvedValueOnce(failure(500))
        .mockResolvedValueOnce(completion({ content: 'Enfin.' }));
      global.fetch = fetchMock;

      await expect(client().reply(input())).resolves.toMatchObject({ text: 'Enfin.' });
      expect(fetchMock).toHaveBeenCalledTimes(3);
      expect(wait).toHaveBeenCalledTimes(2);
    });

    it('429 qui persiste : 503 après trois essais, le quota global du fournisseur n’est pas « ta limite du jour »', async () => {
      const fetchMock = jest.fn().mockResolvedValue(failure(429));
      global.fetch = fetchMock;

      await expect(client().reply(input())).rejects.toBeInstanceOf(ServiceUnavailableException);
      expect(fetchMock).toHaveBeenCalledTimes(3);
    });

    it('panne APRÈS un tour déjà servi : l’exception porte les jetons consommés, que le quota ne rendra pas', async () => {
      global.fetch = jest
        .fn()
        .mockResolvedValueOnce(
          completion(
            { content: null, tool_calls: [toolCall('abc123XYZ', 'get_personal_records', '{}')] },
            'tool_calls',
            { prompt_tokens: 9000, completion_tokens: 1800 },
          ),
        )
        .mockResolvedValue(failure(429));

      const error = await client()
        .reply(input())
        .catch((caught: unknown) => caught);

      expect(error).toBeInstanceOf(CoachProviderUnavailableException);
      expect((error as CoachProviderUnavailableException).usage).toEqual({
        inputTokens: 9000,
        outputTokens: 1800,
        cacheReadTokens: 0,
      });
    });

    it('un refus du fournisseur (400, 401) : 503 tout de suite, sans insister', async () => {
      const fetchMock = jest.fn().mockResolvedValue(failure(401));
      global.fetch = fetchMock;

      await expect(client().reply(input())).rejects.toBeInstanceOf(ServiceUnavailableException);
      expect(fetchMock).toHaveBeenCalledTimes(1);
    });

    it.each<[string, () => Promise<unknown>]>([
      ['réseau coupé', () => Promise.reject(new TypeError('fetch failed'))],
      [
        'échéance dépassée',
        () => Promise.reject(new DOMException('The operation timed out.', 'TimeoutError')),
      ],
      [
        'corps illisible',
        () =>
          Promise.resolve({
            ok: true,
            status: 200,
            json: () => Promise.reject(new SyntaxError('x')),
          }),
      ],
      [
        'corps JSON null (passerelle non conforme)',
        () => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(null) }),
      ],
      [
        // Enum de Mistral : le texte est tronqué, il ne s'archive pas.
        'génération interrompue (finish_reason « error »)',
        () => Promise.resolve(completion({ content: 'Pour ta séance, fais d' }, 'error')),
      ],
    ])('%s : 503', async (_cas, reponse) => {
      global.fetch = jest.fn(reponse) as unknown as typeof fetch;

      await expect(client().reply(input())).rejects.toBeInstanceOf(ServiceUnavailableException);
    });

    it('le message d’erreur (journalisé) porte le statut, jamais la clé ni le corps de la réponse', async () => {
      const refus = failure(422, '{"message":"J’ai mal au genou depuis mardi"}');
      global.fetch = jest.fn().mockResolvedValue(refus);

      const error = (await client()
        .reply(input())
        .catch((caught: unknown) => caught)) as ServiceUnavailableException;

      expect(error.message).toContain('422');
      expect(error.message).not.toContain('cle-mistral-factice');
      expect(error.message).not.toContain('genou');
      // Le corps d'un refus n'est pas même lu : il est abandonné.
      expect(refus.json).not.toHaveBeenCalled();
      expect(refus.body.cancel).toHaveBeenCalled();
    });

    it('429 définitif : le journal porte les en-têtes de limites, et eux seuls', async () => {
      global.fetch = jest.fn().mockResolvedValue(
        failure(429, '{"message":"Rate limit exceeded","code":"1300"}', {
          'x-ratelimit-limit-req-minute': '0',
          'x-ratelimit-remaining-req-minute': '0',
          'content-type': 'application/json',
          'set-cookie': 'session=secret',
        }),
      );

      const error = (await client()
        .reply(input())
        .catch((caught: unknown) => caught)) as ServiceUnavailableException;

      expect(error.message).toBe(
        'Coach : le fournisseur a répondu 429 (Rate limit exceeded) ' +
          '[x-ratelimit-limit-req-minute=0, x-ratelimit-remaining-req-minute=0].',
      );
    });

    it.each([
      ['corps HTML d’une passerelle', 502, '<html>Bad Gateway</html>', ''],
      ['message qui n’est pas un texte', 503, '{"message":{"detail":"x"}}', ''],
      [
        'raison trop longue',
        503,
        JSON.stringify({ message: 'x'.repeat(500) }),
        ` (${'x'.repeat(160)})`,
      ],
    ])(
      '5xx définitif, %s : le statut, et la raison seulement si elle se lit',
      async (_cas, statut, corps, raison) => {
        global.fetch = jest.fn().mockResolvedValue(failure(statut, corps));

        const error = (await client()
          .reply(input())
          .catch((caught: unknown) => caught)) as ServiceUnavailableException;

        expect(error.message).toBe(`Coach : le fournisseur a répondu ${statut}${raison}.`);
      },
    );

    it.each([
      [
        'Mistral',
        '{"object":"error","message":"Service tier capacity exceeded for this model.","code":"3505"}',
      ],
      ['OpenAI', '{"error":{"message":"Service tier capacity exceeded for this model."}}'],
    ])(
      '429 qui persiste (%s) : le journal dit pourquoi, le message du fournisseur seul',
      async (_format, corps) => {
        global.fetch = jest.fn().mockResolvedValue(failure(429, corps));

        const error = (await client()
          .reply(input())
          .catch((caught: unknown) => caught)) as ServiceUnavailableException;

        expect(error.message).toBe(
          'Coach : le fournisseur a répondu 429 (Service tier capacity exceeded for this model.).',
        );
      },
    );
  });

  describe('plusieurs workers (ADR 0013)', () => {
    const A = 'http://ollama:11434/v1';
    const B = 'http://gpu-2.interne:11434/v1';
    const pooled = (pool: CoachWorkerPool) =>
      new OpenAiCompatibleCoachClient(
        {
          coachProvider: { model: 'qwen3' },
          coachGateway: { requestTimeoutMs: STREAM_TIMEOUT_MS, maxOutputTokens: 512 },
        } as unknown as AppConfigService,
        pool,
      );

    it('un worker injoignable : la tentative suivante part sur un autre, qui sert le tour', async () => {
      const pool = new CoachWorkerPool([A, B], 30_000);
      const fetchMock = jest
        .fn()
        .mockRejectedValueOnce(new TypeError('fetch failed'))
        .mockResolvedValueOnce(completion({ content: 'Salut.' }));
      global.fetch = fetchMock;

      const output = await pooled(pool).reply(input());

      expect(output.worker).toBe('gpu-2.interne:11434');
      expect(sent(fetchMock, 0).url).toBe(`${A}/chat/completions`);
      expect(sent(fetchMock, 1).url).toBe(`${B}/chat/completions`);
      expect(sent(fetchMock, 1).body.max_tokens).toBe(512);
      // Le premier est écarté le temps de sa remise en route ; aucun n'est
      // resté compté comme occupé.
      expect(pool.status()).toEqual([
        expect.objectContaining({ url: A, healthy: false, active: 0 }),
        expect.objectContaining({ url: B, healthy: true, active: 0 }),
      ]);
    });

    it('une ANNULATION arrête tout : pas de nouvelle tentative, et le worker n’est pas mis en cause', async () => {
      const pool = new CoachWorkerPool([A, B], 30_000);
      const controller = new AbortController();
      const fetchMock = jest.fn((_url: string, init: RequestInit) => {
        controller.abort();
        return Promise.reject(new DOMException(String(init.signal?.aborted), 'AbortError'));
      });
      global.fetch = fetchMock as unknown as typeof fetch;

      await expect(pooled(pool).reply(input({ signal: controller.signal }))).rejects.toBeInstanceOf(
        CoachProviderUnavailableException,
      );

      expect(fetchMock).toHaveBeenCalledTimes(1);
      // Le signal transmis au worker est bien celui qui porte l'annulation.
      expect((fetchMock.mock.calls[0]?.[1] as RequestInit).signal?.aborted).toBe(true);
      expect(pool.status().every((worker) => worker.healthy)).toBe(true);
    });
  });
});
