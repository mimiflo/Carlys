import { type PinoLogger } from 'nestjs-pino';
import { type DeviceTokensRepository } from '../infrastructure/device-tokens.repository';
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

function buildService(tokens: TokenStubs, sender: SenderStub): NotificationsService {
  // Le stub satisfait déjà structurellement `PushSenderPort`.
  return new NotificationsService(
    tokens as unknown as DeviceTokensRepository,
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

    await service.sendToUser(USER, MESSAGE);

    expect(tokens.listTokens).not.toHaveBeenCalled();
    expect(sender.send).not.toHaveBeenCalled();
  });

  it('envoie à TOUS les appareils de la personne', async () => {
    const tokens = buildTokens();
    tokens.listTokens.mockResolvedValue(['jeton-a', 'jeton-b']);
    const sender = buildSender();
    const service = buildService(tokens, sender);

    await service.sendToUser(USER, MESSAGE);

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

    await service.sendToUser(USER, MESSAGE);

    expect(tokens.deleteByToken).toHaveBeenCalledTimes(1);
    expect(tokens.deleteByToken).toHaveBeenCalledWith('jeton-mort');
  });

  it('un échec d’envoi simple ne purge rien', async () => {
    const tokens = buildTokens();
    tokens.listTokens.mockResolvedValue(['jeton-a']);
    const sender = buildSender();
    sender.send.mockResolvedValue('failed');
    const service = buildService(tokens, sender);

    await service.sendToUser(USER, MESSAGE);
    expect(tokens.deleteByToken).not.toHaveBeenCalled();
  });

  it('ne lève JAMAIS : une base indisponible est journalisée, pas propagée', async () => {
    const tokens = buildTokens();
    tokens.listTokens.mockRejectedValue(new Error('base indisponible'));
    const service = buildService(tokens, buildSender());

    await expect(service.sendToUser(USER, MESSAGE)).resolves.toBeUndefined();
    expect(loggerStub.error).toHaveBeenCalled();
  });
});
