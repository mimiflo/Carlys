import { ServiceUnavailableException } from '@nestjs/common';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { type AppConfigService } from '../../../config/app-config.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { CoachAvailability } from './coach.availability';

const ABONNE = {
  entitlementsFor: () =>
    Promise.resolve({ entitlements: [{ key: 'ai_coaching', isActive: true }] }),
} as unknown as EntitlementsService;

function porte(config: {
  coachProvider: { baseUrl?: string; apiKey?: string; model?: string; visionModel?: string };
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

/**
 * Le message d'une porte fermée est écrit POUR LA PERSONNE : un 503
 * ordinaire voit son message remplacé par « Une erreur interne est
 * survenue. » (filtre d'exceptions) — c'est ce que l'écran du scan affichait
 * le 4 octobre, sur un serveur sans modèle de vision.
 */
describe('CoachAvailability, la porte fermée se dit', () => {
  it('scan sans modèle de vision : « momentanément indisponible », lisible', async () => {
    const refus = porte({
      coachProvider: { baseUrl: 'http://ollama:11434/v1', model: 'qwen3:4b' },
    }).assertVisionAvailable('u');
    await expect(refus).rejects.toBeInstanceOf(UserFacingUnavailableException);
    await expect(refus).rejects.toThrow('Le scan d’assiette est momentanément indisponible.');
  });

  it('coach sans worker : son message passe aussi le filtre', async () => {
    await expect(porte({ coachProvider: {} }).assertAvailable('u')).rejects.toBeInstanceOf(
      UserFacingUnavailableException,
    );
  });
});
