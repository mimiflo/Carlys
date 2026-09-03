import { NotFoundException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { type CoachRepository } from '../infrastructure/coach.repository';
import { type CoachQuota } from './coach.quota';
import { CoachService } from './coach.service';
import { type CoachTools } from './coach.tools';

const USER = 'utilisateur-1';
const CONVERSATION = 'fil-1';
const OTHER_CONVERSATION = 'fil-d-autrui';
const MESSAGE = 'message-1';

interface Stubs {
  repository: {
    ensureConversation: jest.Mock;
    findConversation: jest.Mock;
    carlysProfileOf: jest.Mock;
    conversationIdOfMessage: jest.Mock;
    saveUserMessage: jest.Mock;
    saveAssistantMessage: jest.Mock;
    catalogueNames: jest.Mock;
  };
  quota: { consume: jest.Mock };
  model: { reply: jest.Mock };
}

function storedMessage(role: 'USER' | 'ASSISTANT', content: string) {
  return {
    id: `${role}-${content.length}`,
    conversationId: CONVERSATION,
    role,
    content,
    inputTokens: null,
    outputTokens: null,
    createdAt: new Date('2026-08-09T10:00:00.000Z'),
    proposal: null,
  };
}

function buildStubs(): Stubs {
  return {
    repository: {
      ensureConversation: jest.fn().mockResolvedValue(undefined),
      findConversation: jest.fn().mockResolvedValue({
        id: CONVERSATION,
        userId: USER,
        title: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        deletedAt: null,
        messages: [],
      }),
      carlysProfileOf: jest.fn().mockResolvedValue(null),
      conversationIdOfMessage: jest.fn().mockResolvedValue(null),
      saveUserMessage: jest.fn().mockResolvedValue(storedMessage('USER', 'Salut coach.')),
      saveAssistantMessage: jest.fn().mockResolvedValue(storedMessage('ASSISTANT', 'Salut.')),
      catalogueNames: jest.fn().mockResolvedValue(new Map()),
    },
    quota: { consume: jest.fn().mockResolvedValue(29) },
    model: {
      reply: jest.fn().mockResolvedValue({
        text: 'Salut.',
        proposal: null,
        usage: { inputTokens: 10, outputTokens: 5, cacheReadTokens: 0 },
        refused: false,
      }),
    },
  };
}

function buildService(stubs: Stubs): CoachService {
  const entitlements = {
    entitlementsFor: jest
      .fn()
      .mockResolvedValue({ entitlements: [{ key: 'ai_coaching', isActive: true }] }),
  };
  const config = { coachEnabled: true, anthropicApiKey: 'cle-factice-de-test-32-caracteres' };
  const logger = { info: jest.fn(), warn: jest.fn() };
  return new CoachService(
    stubs.repository as unknown as CoachRepository,
    { run: jest.fn().mockResolvedValue([]) } as unknown as CoachTools,
    stubs.quota as unknown as CoachQuota,
    entitlements as unknown as EntitlementsService,
    config as unknown as AppConfigService,
    stubs.model,
    logger as unknown as PinoLogger,
  );
}

/**
 * L'identifiant de message vient de l'appareil et n'est unique que
 * globalement : un identifiant déjà porté par un autre fil ne doit ni
 * restituer le message d'autrui, ni coûter un tour, ni appeler le modèle.
 */
describe('CoachService.sendMessage', () => {
  it('un identifiant porté par un AUTRE fil : 404 opaque, avant le compteur et sans appel au modèle', async () => {
    const stubs = buildStubs();
    stubs.repository.conversationIdOfMessage.mockResolvedValue(OTHER_CONVERSATION);
    const service = buildService(stubs);

    await expect(service.sendMessage(USER, CONVERSATION, MESSAGE, 'Bonjour')).rejects.toThrow(
      NotFoundException,
    );
    await expect(service.sendMessage(USER, CONVERSATION, MESSAGE, 'Bonjour')).rejects.toThrow(
      'Conversation introuvable.',
    );
    expect(stubs.quota.consume).not.toHaveBeenCalled();
    expect(stubs.repository.saveUserMessage).not.toHaveBeenCalled();
    expect(stubs.model.reply).not.toHaveBeenCalled();
  });

  it('rejouer SON identifiant dans SON fil passe : c’est le cas nominal du hors-ligne', async () => {
    const stubs = buildStubs();
    stubs.repository.conversationIdOfMessage.mockResolvedValue(CONVERSATION);
    const service = buildService(stubs);

    const reply = await service.sendMessage(USER, CONVERSATION, MESSAGE, 'Salut coach.');

    expect(reply.userMessage.content).toBe('Salut coach.');
    expect(reply.assistantMessage.content).toBe('Salut.');
    expect(reply.remainingToday).toBe(29);
    expect(stubs.repository.saveUserMessage).toHaveBeenCalledWith(
      CONVERSATION,
      MESSAGE,
      'Salut coach.',
    );
  });

  it('course perdue à l’écriture (le dépôt rend null) : même 404, rien n’est renvoyé', async () => {
    const stubs = buildStubs();
    stubs.repository.saveUserMessage.mockResolvedValue(null);
    const service = buildService(stubs);

    await expect(service.sendMessage(USER, CONVERSATION, MESSAGE, 'Bonjour')).rejects.toThrow(
      NotFoundException,
    );
    expect(stubs.model.reply).not.toHaveBeenCalled();
  });
});
