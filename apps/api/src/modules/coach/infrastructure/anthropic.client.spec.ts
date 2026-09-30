import { ServiceUnavailableException } from '@nestjs/common';
import { type AppConfigService } from '../../../config/app-config.service';
import { CoachProviderUnavailableException, type CoachTurnInput } from '../domain/coach-model.port';
import { AnthropicCoachClient } from './anthropic.client';

const INPUT: CoachTurnInput = {
  system: 'Tu es le coach.',
  tools: [],
  history: [{ role: 'user', content: 'Salut.' }],
  runTools: () => Promise.resolve([]),
};

function client(model?: string): AnthropicCoachClient {
  return new AnthropicCoachClient({
    anthropicApiKey: 'sk-ant-cle-factice-de-test',
    coachProvider: { model },
  } as unknown as AppConfigService);
}

function jsonResponse(status: number, payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

/**
 * Le client Anthropic, vu à travers un `fetch` simulé : le SDK n'est pas
 * remplacé, seul le réseau l'est.
 */
describe('AnthropicCoachClient', () => {
  const originalFetch = global.fetch;
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('sans COACH_MODEL, demande claude-opus-5-5 (le défaut vit ici, pas dans le schéma), avec le repli serveur sur refus', async () => {
    const fetchMock = jest.fn().mockResolvedValue(
      jsonResponse(200, {
        id: 'msg_1',
        type: 'message',
        role: 'assistant',
        model: 'claude-opus-5',
        content: [{ type: 'text', text: 'Salut !' }],
        stop_reason: 'end_turn',
        usage: { input_tokens: 12, output_tokens: 3 },
      }),
    );
    global.fetch = fetchMock;

    const output = await client().reply(INPUT);

    expect(output.text).toBe('Salut !');
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(JSON.parse(init.body as string)).toMatchObject({
      model: 'claude-opus-5-5',
      // Un refus d'un classifieur de sécurité (faux positif sur une question
      // de compléments, de blessure…) est repris par un autre modèle dans le
      // même appel, au lieu de rendre « Je ne peux pas répondre ».
      fallbacks: 'default',
      output_config: { effort: 'medium' },
    });
    expect(new Headers(init.headers).get('anthropic-beta')).toContain(
      'server-side-fallback-2026-07-01',
    );
  });

  it('l’échéance du tour est bien passée au SDK : échue, aucun appel ne part et le tour rend 503', async () => {
    // Sans elle, le SDK attendrait 10 min : bien au-delà des 60 s de nginx.
    const timeout = jest.spyOn(AbortSignal, 'timeout').mockReturnValue(AbortSignal.abort());
    const fetchMock = jest.fn().mockResolvedValue(
      jsonResponse(200, {
        id: 'msg_1',
        type: 'message',
        role: 'assistant',
        model: 'claude-opus-5',
        content: [{ type: 'text', text: 'Trop tard.' }],
        stop_reason: 'end_turn',
        usage: { input_tokens: 12, output_tokens: 3 },
      }),
    );
    global.fetch = fetchMock;

    const reply = client().reply(INPUT);

    await expect(reply).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(fetchMock).not.toHaveBeenCalled();
    timeout.mockRestore();
  });

  it('une erreur du fournisseur devient un 503 (SERVICE_UNAVAILABLE), jamais un 500', async () => {
    // 401 : pas de nouvelle tentative du SDK, le test reste instantané.
    global.fetch = jest
      .fn()
      .mockResolvedValue(
        jsonResponse(401, { type: 'error', error: { type: 'authentication_error' } }),
      );

    await expect(client('claude-opus-5').reply(INPUT)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('panne APRÈS un tour d’outils servi : l’exception porte les jetons déjà consommés', async () => {
    global.fetch = jest
      .fn()
      .mockResolvedValueOnce(
        jsonResponse(200, {
          id: 'msg_1',
          type: 'message',
          role: 'assistant',
          model: 'claude-opus-5',
          content: [{ type: 'tool_use', id: 'toolu_1', name: 'get_personal_records', input: {} }],
          stop_reason: 'tool_use',
          usage: { input_tokens: 9000, output_tokens: 1800, cache_read_input_tokens: 700 },
        }),
      )
      .mockResolvedValue(
        jsonResponse(401, { type: 'error', error: { type: 'authentication_error' } }),
      );

    const error = await client('claude-opus-5')
      .reply(INPUT)
      .catch((caught: unknown) => caught);

    expect(error).toBeInstanceOf(CoachProviderUnavailableException);
    expect((error as CoachProviderUnavailableException).usage).toEqual({
      inputTokens: 9000,
      outputTokens: 1800,
      cacheReadTokens: 700,
    });
  });
});
