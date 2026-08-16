import { type PinoLogger } from 'nestjs-pino';
import { type DeviceTokensRepository } from '../infrastructure/device-tokens.repository';
import { type NotificationPreferencesRepository } from '../infrastructure/notification-preferences.repository';
import { NotificationsService } from './notifications.service';

const USER = 'utilisateur-1';
const MESSAGE = { title: 'Titre', body: 'Corps' };

interface TokenStubs {
  upsert: jest.Mock;
  deleteForUser: jest.Mock;
  deleteByToken: jest.Mock;
  listTokens: jest.Mock;
}

function buildTokens(): TokenStubs {
  return {
    upsert: jest.fn().mockResolvedValue(undefined),
    deleteForUser: jest.fn().mockResolvedValue(undefined),
    deleteByToken: jest.fn().mockResolvedValue(undefined),
    listTokens: jest.fn().mockResolvedValue([]),
  };
}

interface SenderStub {
  enabled: boolean;
  send: jest.Mock;
}

function buildSender(enabled = true): SenderStub {
  return { enabled, send: jest.fn().mockResolvedValue('sent') };
}

const loggerStub = { error: jest.fn() };

interface PreferenceStubs {
  disabledCategories: jest.Mock;
  isEnabled: jest.Mock;
  set: jest.Mock;
}

function buildPreferences(enabled = true): PreferenceStubs {
  return {
    disabledCategories: jest.fn().mockResolvedValue(new Set()),
    isEnabled: jest.fn().mockResolvedValue(enabled),
    set: jest.fn().mockResolvedValue(undefined),
  };
}

function buildService(
  tokens: TokenStubs,
  sender: SenderStub,
  preferences: PreferenceStubs = buildPreferences(),
): NotificationsService {
  // Le stub satisfait déjà structurellement `PushSenderPort`.
  return new NotificationsService(
    tokens as unknown as DeviceTokensRepository,
    preferences as unknown as NotificationPreferencesRepository,
    sender,
    loggerStub as unknown as PinoLogger,
  );
}

describe('NotificationsService — jetons d’appareil', () => {
  it('enregistre le jeton pour l’utilisateur appelant', async () => {
    const tokens = buildTokens();
    const service = buildService(tokens, buildSender());

    await service.registerDevice(USER, { token: 'jeton-a', platform: 'ANDROID' });

    expect(tokens.upsert).toHaveBeenCalledWith({
      userId: USER,
      token: 'jeton-a',
      platform: 'ANDROID',
    });
  });

  it('l’oubli est limité aux jetons de l’appelant', async () => {
    const tokens = buildTokens();
    const service = buildService(tokens, buildSender());

    await service.forgetDevice(USER, 'jeton-a');
    expect(tokens.deleteForUser).toHaveBeenCalledWith(USER, 'jeton-a');
  });
});

describe('NotificationsService — envoi', () => {
  it('sans compte de service configuré, rien n’est lu ni envoyé', async () => {
    const tokens = buildTokens();
    const sender = buildSender(false);
    const service = buildService(tokens, sender);

    await service.sendToUser(USER, MESSAGE, 'ENCOURAGEMENTS');

    expect(tokens.listTokens).not.toHaveBeenCalled();
    expect(sender.send).not.toHaveBeenCalled();
  });

  it('envoie à TOUS les appareils de la personne', async () => {
    const tokens = buildTokens();
    tokens.listTokens.mockResolvedValue(['jeton-a', 'jeton-b']);
    const sender = buildSender();
    const service = buildService(tokens, sender);

    await service.sendToUser(USER, MESSAGE, 'ENCOURAGEMENTS');

    expect(sender.send).toHaveBeenCalledTimes(2);
    expect(sender.send).toHaveBeenCalledWith('jeton-a', MESSAGE);
    expect(sender.send).toHaveBeenCalledWith('jeton-b', MESSAGE);
  });

  it('un jeton que FCM déclare mort est purgé — les autres restent', async () => {
    const tokens = buildTokens();
    tokens.listTokens.mockResolvedValue(['jeton-mort', 'jeton-vif']);
    const sender = buildSender();
    sender.send.mockResolvedValueOnce('invalid-token').mockResolvedValueOnce('sent');
    const service = buildService(tokens, sender);

    await service.sendToUser(USER, MESSAGE, 'ENCOURAGEMENTS');

    expect(tokens.deleteByToken).toHaveBeenCalledTimes(1);
    expect(tokens.deleteByToken).toHaveBeenCalledWith('jeton-mort');
  });

  it('un échec d’envoi simple ne purge rien', async () => {
    const tokens = buildTokens();
    tokens.listTokens.mockResolvedValue(['jeton-a']);
    const sender = buildSender();
    sender.send.mockResolvedValue('failed');
    const service = buildService(tokens, sender);

    await service.sendToUser(USER, MESSAGE, 'ENCOURAGEMENTS');
    expect(tokens.deleteByToken).not.toHaveBeenCalled();
  });

  it('ne lève JAMAIS : une base indisponible est journalisée, pas propagée', async () => {
    const tokens = buildTokens();
    tokens.listTokens.mockRejectedValue(new Error('base indisponible'));
    const service = buildService(tokens, buildSender());

    await expect(service.sendToUser(USER, MESSAGE, 'ENCOURAGEMENTS')).resolves.toBeUndefined();
    expect(loggerStub.error).toHaveBeenCalled();
  });
});

describe('NotificationsService — ce que la personne refuse', () => {
  it('une catégorie refusée ne part PAS, même avec des jetons valides', async () => {
    // La coupure doit vivre côté serveur : une préférence que seul le
    // téléphone connaîtrait laisserait la notification arriver quand même.
    const tokens = buildTokens();
    tokens.listTokens.mockResolvedValue(['jeton-1']);
    const sender = buildSender();
    const service = buildService(tokens, sender, buildPreferences(false));

    await service.sendToUser(USER, MESSAGE, 'ENCOURAGEMENTS');

    expect(sender.send).not.toHaveBeenCalled();
  });

  it('une catégorie jamais réglée vaut ACCEPTÉE', async () => {
    // Personne ne doit ouvrir les réglages pour que l'application se
    // comporte normalement, et une catégorie ajoutée plus tard ne doit pas
    // arriver coupée pour tout le monde.
    const preferences = buildPreferences();
    const service = buildService(buildTokens(), buildSender(), preferences);

    const result = await service.preferencesOf(USER);

    expect(result.preferences).toEqual([
      { category: 'FRIEND_REQUESTS', enabled: true },
      { category: 'ENCOURAGEMENTS', enabled: true },
    ]);
  });

  it('les refus enregistrés ressortent, les autres restent acceptés', async () => {
    const preferences = buildPreferences();
    preferences.disabledCategories.mockResolvedValue(new Set(['ENCOURAGEMENTS']));
    const service = buildService(buildTokens(), buildSender(), preferences);

    const result = await service.preferencesOf(USER);

    expect(result.preferences).toContainEqual({ category: 'ENCOURAGEMENTS', enabled: false });
    expect(result.preferences).toContainEqual({ category: 'FRIEND_REQUESTS', enabled: true });
  });
});
