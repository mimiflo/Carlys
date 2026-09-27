import { type AppConfigService } from '../../config/app-config.service';
import { coachModelFor } from './coach.module';
import { AnthropicCoachClient } from './infrastructure/anthropic.client';
import { OpenAiCompatibleCoachClient } from './infrastructure/openai-compatible.client';

const config = (coachProvider: { baseUrl?: string }) =>
  ({ coachProvider }) as unknown as AppConfigService;

/** Le fournisseur est un RÉGLAGE : une seule variable décide, aucun code ne change. */
describe('coachModelFor', () => {
  it('COACH_API_BASE_URL posée : le client compatible OpenAI (Mistral, Ollama, Cloudflare)', () => {
    expect(coachModelFor(config({ baseUrl: 'https://api.mistral.ai/v1' }))).toBeInstanceOf(
      OpenAiCompatibleCoachClient,
    );
  });

  it('COACH_API_BASE_URL absente : Anthropic, comme avant', () => {
    expect(coachModelFor(config({}))).toBeInstanceOf(AnthropicCoachClient);
  });
});
