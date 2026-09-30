import { ServiceUnavailableException } from '@nestjs/common';
import { type AppConfigService } from '../../../config/app-config.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { CoachAvailability } from './coach.availability';

const ABONNE = {
  entitlementsFor: () =>
    Promise.resolve({ entitlements: [{ key: 'ai_coaching', isActive: true }] }),
} as unknown as EntitlementsService;

function porte(config: {
  anthropicApiKey?: string;
  coachProvider: { baseUrl?: string; apiKey?: string; model?: string };
}): CoachAvailability {
  const { baseUrl } = config.coachProvider;
  return new CoachAvailability(ABONNE, {
    coachEnabled: true,
    coachGateway: { workerUrls: baseUrl === undefined ? [] : [baseUrl] },
    ...config,
  } as unknown as AppConfigService);
}

/**
 * Le fournisseur est un RÉGLAGE : une adresse compatible OpenAI (Mistral…)
 * choisit ce client, son absence garde Anthropic. Dans les deux cas, un
 * réglage incomplet ferme la porte (503) avant toute dépense, sans empêcher
 * l'API de démarrer.
 */
describe('CoachAvailability, le fournisseur configuré', () => {
  it('Anthropic (aucune adresse) : ouvert avec sa clé, fermé sans', async () => {
    await expect(
      porte({ anthropicApiKey: 'sk-ant-factice', coachProvider: {} }).assertAvailable('u'),
    ).resolves.toBeUndefined();
    await expect(porte({ coachProvider: {} }).assertAvailable('u')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('adresse compatible OpenAI : il faut aussi un modèle, et la clé Anthropic ne compte plus', async () => {
    const mistral = { baseUrl: 'https://api.mistral.ai/v1', apiKey: 'cle-factice' };

    await expect(
      porte({ coachProvider: { ...mistral, model: 'mistral-small-latest' } }).assertAvailable('u'),
    ).resolves.toBeUndefined();
    // Sans modèle, rien à demander au fournisseur : fermé, même avec une clé
    // Anthropic restée dans le .env.
    await expect(
      porte({ anthropicApiKey: 'sk-ant-factice', coachProvider: mistral }).assertAvailable('u'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('adresse sans clé (Ollama sur le réseau interne) : ouvert', async () => {
    await expect(
      porte({
        coachProvider: { baseUrl: 'http://ollama:11434/v1', model: 'ministral-3:8b' },
      }).assertAvailable('u'),
    ).resolves.toBeUndefined();
  });
});
