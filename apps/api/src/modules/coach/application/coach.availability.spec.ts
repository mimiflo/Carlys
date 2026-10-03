import { ServiceUnavailableException } from '@nestjs/common';
import { type AppConfigService } from '../../../config/app-config.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { CoachAvailability } from './coach.availability';

const ABONNE = {
  entitlementsFor: () =>
    Promise.resolve({ entitlements: [{ key: 'ai_coaching', isActive: true }] }),
} as unknown as EntitlementsService;

function porte(config: {
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
 * Un seul fournisseur, nos workers : un réglage incomplet ferme la porte
 * (503) avant toute dépense, sans empêcher l'API de démarrer.
 */
describe('CoachAvailability, le fournisseur configuré', () => {
  it('aucun worker : fermé — il n’existe aucun autre fournisseur', async () => {
    await expect(porte({ coachProvider: {} }).assertAvailable('u')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('un worker sans modèle : fermé, rien à lui demander', async () => {
    await expect(
      porte({ coachProvider: { baseUrl: 'http://ollama:11434/v1' } }).assertAvailable('u'),
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
