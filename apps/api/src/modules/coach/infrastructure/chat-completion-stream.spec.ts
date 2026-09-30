import { ServiceUnavailableException } from '@nestjs/common';
import { type AppConfigService } from '../../../config/app-config.service';
import { CoachProviderUnavailableException } from '../domain/coach-model.port';
import { readChatStream } from './chat-completion-stream';
import { OpenAiCompatibleCoachClient } from './openai-compatible.client';

/** Une réponse SSE découpée comme le réseau la découpe : n'importe où. */
function sse(lines: string[], cutEvery = 7): Response {
  const text = lines.map((line) => `${line}\n\n`).join('');
  const bytes = new TextEncoder().encode(text);
  return new Response(
    new ReadableStream({
      start(controller) {
        for (let i = 0; i < bytes.length; i += cutEvery) {
          controller.enqueue(bytes.slice(i, i + cutEvery));
        }
        controller.close();
      },
    }),
    { headers: { 'Content-Type': 'text/event-stream' } },
  );
}

const data = (chunk: unknown) => `data: ${JSON.stringify(chunk)}`;
const delta = (content: string) => data({ choices: [{ delta: { content }, finish_reason: null }] });
const fin = (reason = 'stop') => data({ choices: [{ delta: {}, finish_reason: reason }] });

/**
 * Le flux Chat Completions tel qu'Ollama 0.34 l'écrit : `data: <json>`, fin en
 * `data: [DONE]`, usage dans un morceau à part quand on le demande.
 */
describe('readChatStream', () => {
  it('rend chaque morceau de texte dès qu’il arrive, et la réponse entière à la fin', async () => {
    const seen: string[] = [];
    const completion = await readChatStream(
      sse([
        delta('Bon'),
        delta('jour '),
        delta('Léa'),
        fin(),
        data({ choices: [], usage: { prompt_tokens: 30, completion_tokens: 3 } }),
        'data: [DONE]',
      ]),
      (text) => seen.push(text),
    );

    expect(seen).toEqual(['Bon', 'jour ', 'Léa']);
    expect(completion.choices?.[0]?.message?.content).toBe('Bonjour Léa');
    expect(completion.choices?.[0]?.finish_reason).toBe('stop');
    expect(completion.usage).toEqual({ prompt_tokens: 30, completion_tokens: 3 });
  });

  it('assemble les appels d’outils, entiers (Ollama) ou en fragments', async () => {
    const completion = await readChatStream(
      sse([
        data({
          choices: [
            {
              delta: {
                tool_calls: [
                  {
                    index: 0,
                    id: 'a',
                    function: { name: 'list_workouts', arguments: '{"limit":5}' },
                  },
                  { index: 1, id: 'b', function: { name: 'propose_session', arguments: '{"ti' } },
                ],
              },
            },
          ],
        }),
        data({
          choices: [
            { delta: { tool_calls: [{ index: 1, function: { arguments: 'tle":"X"}' } }] } },
          ],
        }),
        fin('tool_calls'),
        'data: [DONE]',
      ]),
      () => undefined,
    );

    expect(completion.choices?.[0]?.message?.tool_calls).toEqual([
      { id: 'a', type: 'function', function: { name: 'list_workouts', arguments: '{"limit":5}' } },
      {
        id: 'b',
        type: 'function',
        function: { name: 'propose_session', arguments: '{"title":"X"}' },
      },
    ]);
  });

  it('un flux coupé sans [DONE] ni fin (erreur d’Ollama en cours de route) est une panne', async () => {
    await expect(readChatStream(sse([delta('Bon')]), () => undefined)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('un morceau illisible est une panne, pas un 500', async () => {
    await expect(
      readChatStream(sse(['data: {pas du json']), () => undefined),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});

describe('OpenAiCompatibleCoachClient en flux', () => {
  afterEach(() => jest.restoreAllMocks());

  it('demande le flux et son usage, relaie le texte, et garde la boucle d’outils', async () => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce(
        sse([
          delta('Je regarde… '),
          data({
            choices: [
              {
                delta: {
                  tool_calls: [
                    {
                      index: 0,
                      id: 'c1',
                      function: { name: 'get_personal_records', arguments: '{}' },
                    },
                  ],
                },
              },
            ],
          }),
          fin('tool_calls'),
          'data: [DONE]',
        ]),
      )
      .mockResolvedValueOnce(
        sse([
          delta('Ton record : 100 kg.'),
          fin(),
          data({ choices: [], usage: { prompt_tokens: 50, completion_tokens: 8 } }),
          'data: [DONE]',
        ]),
      );
    const seen: string[] = [];
    const runTools = jest.fn().mockResolvedValue([{ id: 'c1', content: '{"records":[]}' }]);

    const output = await new OpenAiCompatibleCoachClient({
      coachProvider: { baseUrl: 'http://ollama:11434/v1', model: 'qwen3' },
    } as unknown as AppConfigService).reply({
      system: 'Tu es le coach.',
      tools: [],
      history: [{ role: 'user', content: 'Mon record ?' }],
      runTools,
      onText: (text) => seen.push(text),
    });

    const body = JSON.parse(fetchMock.mock.calls[0]?.[1]?.body as string) as Record<
      string,
      unknown
    >;
    expect(body.stream).toBe(true);
    expect(body.stream_options).toEqual({ include_usage: true });
    expect(runTools).toHaveBeenCalledWith([{ id: 'c1', name: 'get_personal_records', input: {} }]);
    // Deux tours qui parlent ne se collent pas : un saut de paragraphe.
    expect(seen).toEqual(['Je regarde… ', '\n\n', 'Ton record : 100 kg.']);
    expect(output.text).toBe('Ton record : 100 kg.');
    expect(output.usage.inputTokens).toBe(50);
  });

  it('un flux coupé après du texte montré n’est pas rendu au quota', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValueOnce(sse([delta('Bon')]));

    const failure = new OpenAiCompatibleCoachClient({
      coachProvider: { baseUrl: 'http://ollama:11434/v1', model: 'qwen3' },
    } as unknown as AppConfigService)
      .reply({
        system: 'Tu es le coach.',
        tools: [],
        history: [{ role: 'user', content: 'Salut' }],
        runTools: jest.fn(),
        onText: () => undefined,
      })
      .catch((error: unknown) => error);

    // `refundIfUnavailable` ne rend qu'à zéro jeton : du texte a coûté.
    await expect(failure).resolves.toBeInstanceOf(CoachProviderUnavailableException);
    await expect(failure).resolves.toMatchObject({ usage: { inputTokens: 1 } });
  });
});
