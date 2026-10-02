import { type AppConfigService } from '../../config/app-config.service';
import { coachModelFor } from './coach.module';
import { AnthropicCoachClient } from './infrastructure/anthropic.client';
import { CoachWorkerPool } from './infrastructure/coach-worker-pool';
import { FallbackCoachModel } from './infrastructure/fallback-coach-model';
import { OpenAiCompatibleCoachClient } from './infrastructure/openai-compatible.client';

const config = (cloudFallback = false, anthropicApiKey?: string) =>
  ({ coachGateway: { cloudFallback }, anthropicApiKey }) as unknown as AppConfigService;
const pool = (...urls: string[]) => new CoachWorkerPool(urls, 30_000);

/** Le fournisseur est un RÉGLAGE : une seule variable décide, aucun code ne change. */
describe('coachModelFor', () => {
  it('un worker au moins : le client compatible OpenAI, sur nos Ollama', () => {
    expect(coachModelFor(config(), pool('http://ollama:11434/v1'))).toBeInstanceOf(
      OpenAiCompatibleCoachClient,
    );
  });

  it('aucun worker : Anthropic, comme avant', () => {
    expect(coachModelFor(config(), pool())).toBeInstanceOf(AnthropicCoachClient);
  });

  it('le repli cloud ne naît qu’ALLUMÉ et avec une clé : jamais de service payant par défaut', () => {
    const workers = pool('http://ollama:11434/v1');
    expect(coachModelFor(config(false, 'sk-ant-factice-1234567890'), workers)).toBeInstanceOf(
      OpenAiCompatibleCoachClient,
    );
    expect(coachModelFor(config(true), workers)).toBeInstanceOf(OpenAiCompatibleCoachClient);
    expect(coachModelFor(config(true, 'sk-ant-factice-1234567890'), workers)).toBeInstanceOf(
      FallbackCoachModel,
    );
  });

  it('le repli demande à Anthropic SON modèle, jamais celui de nos workers', async () => {
    const fetchMock = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          id: 'msg_1',
          type: 'message',
          role: 'assistant',
          content: [{ type: 'text', text: 'Salut !' }],
          stop_reason: 'end_turn',
          usage: { input_tokens: 1, output_tokens: 1 },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      ),
    );
    const original = global.fetch;
    global.fetch = fetchMock;
    const fallbackConfig = {
      coachGateway: {
        cloudFallback: true,
        requestTimeoutMs: 180_000,
        streamIdleTimeoutMs: 60_000,
        maxOutputTokens: 512,
        maxContinuations: 2,
      },
      coachProvider: { model: 'qwen3:4b-instruct-2507-q4_K_M' },
      anthropicApiKey: 'sk-ant-factice-1234567890',
    } as unknown as AppConfigService;
    try {
      // Aucun worker ne répond : le repli prend le tour.
      const model = coachModelFor(fallbackConfig, pool('http://127.0.0.1:1/v1'));
      const failingFetch = jest
        .fn()
        .mockRejectedValueOnce(new TypeError('fetch failed'))
        .mockRejectedValueOnce(new TypeError('fetch failed'))
        .mockRejectedValueOnce(new TypeError('fetch failed'))
        .mockImplementation(fetchMock);
      global.fetch = failingFetch;
      const output = await model.reply({
        system: 's',
        tools: [],
        history: [{ role: 'user', content: 'Salut' }],
        runTools: () => Promise.resolve([]),
      });
      expect(output.model).toBe('claude-opus-5-5');
      const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(JSON.parse(init.body as string)).toMatchObject({ model: 'claude-opus-5-5' });
    } finally {
      global.fetch = original;
    }
  });
});
