import { type AppConfigService } from '../../config/app-config.service';
import { coachModelFor } from './coach.module';
import { CoachWorkerPool } from './infrastructure/coach-worker-pool';
import { OpenAiCompatibleCoachClient } from './infrastructure/openai-compatible.client';

const config = {} as unknown as AppConfigService;
const pool = (...urls: string[]) => new CoachWorkerPool(urls, 30_000);

/** Un seul fournisseur : nos workers. Aucun repli vers un prestataire. */
describe('coachModelFor', () => {
  it('toujours le client compatible OpenAI, sur nos Ollama — même sans worker', () => {
    expect(coachModelFor(config, pool('http://ollama:11434/v1'))).toBeInstanceOf(
      OpenAiCompatibleCoachClient,
    );
    expect(coachModelFor(config, pool())).toBeInstanceOf(OpenAiCompatibleCoachClient);
  });
});
