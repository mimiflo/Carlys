import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { FcmPushSender } from './fcm.sender';

/**
 * CE QUE CE FICHIER PROTÈGE : ce que l'envoyeur remet à FCM.
 *
 * `firebase-admin` est remplacé par un faux `Messaging` qui retient chaque
 * message : aucun test ne sort sur le réseau, et on lit exactement ce qui
 * serait parti. L'enjeu est le champ `data` — la destination du toucher —,
 * qui doit voyager à côté du titre et du corps.
 */

const mockSend = jest.fn();

jest.mock('firebase-admin/app', () => ({
  cert: jest.fn(() => ({})),
  getApps: jest.fn(() => []),
  initializeApp: jest.fn(() => ({ name: 'carlys-push' })),
}));

jest.mock('firebase-admin/messaging', () => ({
  getMessaging: jest.fn(() => ({ send: mockSend })),
}));

function build(): FcmPushSender {
  const config = { firebaseServiceAccountJson: '{"project_id":"carlys-test"}' };
  return new FcmPushSender(
    config as unknown as AppConfigService,
    { error: jest.fn() } as unknown as PinoLogger,
  );
}

describe('FcmPushSender — le message remis à FCM', () => {
  beforeEach(() => {
    mockSend.mockReset();
    mockSend.mockResolvedValue('projects/carlys-test/messages/1');
  });

  it('transmet `data` TEL QUEL, à côté de la notification affichée', async () => {
    const sender = build();

    const outcome = await sender.send('jeton-a', {
      title: 'Nouveau défi',
      body: 'Chloé te défie : Qui court le plus',
      data: { destination: 'friend-challenge', challengeId: 'defi-1' },
    });

    expect(outcome).toBe('sent');
    expect(mockSend).toHaveBeenCalledWith({
      token: 'jeton-a',
      notification: { title: 'Nouveau défi', body: 'Chloé te défie : Qui court le plus' },
      data: { destination: 'friend-challenge', challengeId: 'defi-1' },
    });
  });

  it('sans `data`, le message n’en porte aucun', async () => {
    const sender = build();

    await sender.send('jeton-a', { title: 'Titre', body: 'Corps' });

    expect(mockSend).toHaveBeenCalledWith({
      token: 'jeton-a',
      notification: { title: 'Titre', body: 'Corps' },
    });
  });

  it('un jeton que FCM déclare mort est signalé pour la purge', async () => {
    const sender = build();
    mockSend.mockRejectedValue({ code: 'messaging/registration-token-not-registered' });

    expect(await sender.send('jeton-mort', { title: 'T', body: 'C' })).toBe('invalid-token');
  });
});
