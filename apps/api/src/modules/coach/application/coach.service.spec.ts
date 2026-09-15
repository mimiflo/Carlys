import { ConflictException, NotFoundException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { type CoachTurnInput, type CoachTurnOutput } from '../domain/coach-model.port';
import { type CoachRepository } from '../infrastructure/coach.repository';
import { type CoachQuota } from './coach.quota';
import { CoachAvailability } from './coach.availability';
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
    findMessageWithReply: jest.Mock;
    conversationIdOfMessage: jest.Mock;
    saveUserMessage: jest.Mock;
    saveAssistantMessage: jest.Mock;
    catalogueNames: jest.Mock;
  };
  quota: { consume: jest.Mock; remaining: jest.Mock };
  model: { reply: jest.Mock<Promise<CoachTurnOutput>, [CoachTurnInput]> };
}

function storedMessage(role: 'USER' | 'ASSISTANT', content: string, id = `${role}-${content}`) {
  return {
    id,
    conversationId: CONVERSATION,
    role,
    content,
    inputTokens: null,
    outputTokens: null,
    createdAt: new Date('2026-08-09T10:00:00.000Z'),
    proposal: null,
  };
}

function conversationWith(messages: ReturnType<typeof storedMessage>[]) {
  return {
    id: CONVERSATION,
    userId: USER,
    title: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    messages,
  };
}

function buildStubs(): Stubs {
  return {
    repository: {
      ensureConversation: jest.fn().mockResolvedValue(undefined),
      findConversation: jest.fn().mockResolvedValue(conversationWith([])),
      carlysProfileOf: jest.fn().mockResolvedValue(null),
      findMessageWithReply: jest.fn().mockResolvedValue(null),
      conversationIdOfMessage: jest.fn().mockResolvedValue(null),
      saveUserMessage: jest.fn().mockResolvedValue(storedMessage('USER', 'Salut coach.', MESSAGE)),
      saveAssistantMessage: jest.fn().mockResolvedValue(storedMessage('ASSISTANT', 'Salut.')),
      catalogueNames: jest.fn().mockResolvedValue(new Map()),
    },
    quota: { consume: jest.fn().mockResolvedValue(29), remaining: jest.fn().mockResolvedValue(29) },
    model: {
      reply: jest.fn<Promise<CoachTurnOutput>, [CoachTurnInput]>().mockResolvedValue({
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
  // La porte (configuration + droit) est un collaborateur à part : on lui
  // passe les mêmes doubles qu'avant, la règle testée ne change pas.
  const availability = new CoachAvailability(
    entitlements as unknown as EntitlementsService,
    config as unknown as AppConfigService,
  );
  return new CoachService(
    stubs.repository as unknown as CoachRepository,
    { run: jest.fn().mockResolvedValue([]) } as unknown as CoachTools,
    stubs.quota as unknown as CoachQuota,
    availability,
    stubs.model,
    logger as unknown as PinoLogger,
  );
}

/**
 * L'identifiant de message vient de l'appareil et n'est unique que
 * globalement : un identifiant déjà porté par un autre fil ne doit ni
 * restituer le message d'autrui, ni coûter un tour, ni appeler le modèle.
 * Dans SON fil, le rejeu est idempotent : même réponse, rien de dépensé.
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

  it('rejouer SON message déjà répondu rend la MÊME réponse : ni tour de quota, ni appel au modèle, ni écriture', async () => {
    const stubs = buildStubs();
    const question = storedMessage('USER', 'Salut coach.', MESSAGE);
    const answer = storedMessage('ASSISTANT', 'Salut.', 'reponse-archivee');
    stubs.repository.findMessageWithReply.mockResolvedValue({ message: question, reply: answer });
    stubs.quota.remaining.mockResolvedValue(12);
    const service = buildService(stubs);

    const reply = await service.sendMessage(USER, CONVERSATION, MESSAGE, 'Salut coach.');

    expect(reply.userMessage.id).toBe(MESSAGE);
    expect(reply.assistantMessage.id).toBe('reponse-archivee');
    expect(reply.assistantMessage.content).toBe('Salut.');
    // Le solde du jour, pas un solde décrémenté.
    expect(reply.remainingToday).toBe(12);
    expect(stubs.quota.consume).not.toHaveBeenCalled();
    expect(stubs.model.reply).not.toHaveBeenCalled();
    expect(stubs.repository.saveUserMessage).not.toHaveBeenCalled();
    expect(stubs.repository.saveAssistantMessage).not.toHaveBeenCalled();
  });

  it('le même identifiant avec un AUTRE contenu est une collision : 409, rien de dépensé', async () => {
    const stubs = buildStubs();
    const question = storedMessage('USER', 'Salut coach.', MESSAGE);
    const answer = storedMessage('ASSISTANT', 'Salut.');
    stubs.repository.findMessageWithReply.mockResolvedValue({ message: question, reply: answer });
    const service = buildService(stubs);

    await expect(
      service.sendMessage(USER, CONVERSATION, MESSAGE, 'Une autre question.'),
    ).rejects.toThrow(ConflictException);
    expect(stubs.quota.consume).not.toHaveBeenCalled();
    expect(stubs.model.reply).not.toHaveBeenCalled();
    expect(stubs.repository.saveUserMessage).not.toHaveBeenCalled();
  });

  it('message écrit mais jamais répondu (tour interrompu) : le rejeu termine le tour, sans doubler le message', async () => {
    const stubs = buildStubs();
    const earlier = storedMessage('USER', 'Première question.', 'message-0');
    const earlierAnswer = storedMessage('ASSISTANT', 'Première réponse.');
    const orphan = storedMessage('USER', 'Salut coach.', MESSAGE);
    stubs.repository.findMessageWithReply.mockResolvedValue({ message: orphan, reply: null });
    stubs.repository.findConversation.mockResolvedValue(
      conversationWith([earlier, earlierAnswer, orphan]),
    );
    const service = buildService(stubs);

    const reply = await service.sendMessage(USER, CONVERSATION, MESSAGE, 'Salut coach.');

    expect(reply.assistantMessage.content).toBe('Salut.');
    expect(reply.remainingToday).toBe(29);
    expect(stubs.quota.consume).toHaveBeenCalledTimes(1);
    expect(stubs.repository.saveUserMessage).toHaveBeenCalledWith(
      CONVERSATION,
      MESSAGE,
      'Salut coach.',
    );
    // L'historique envoyé : les deux tours précédents, puis la question, UNE fois.
    const input = stubs.model.reply.mock.calls[0]?.[0];
    expect(input?.history.map((turn) => turn.role)).toEqual(['user', 'assistant', 'user']);
    expect(input?.history.filter((turn) => turn.content.includes('Salut coach.'))).toHaveLength(1);
    expect(stubs.repository.saveAssistantMessage).toHaveBeenCalledTimes(1);
  });

  it('le fil n’est relu que sur une FENÊTRE, jamais en entier', async () => {
    // Le fil n'a aucun plafond, l'historique envoyé au modèle en a un (20
    // tours). Relire des centaines de messages, leurs propositions et les
    // séries de chaque proposition pour en garder vingt, à chaque phrase,
    // c'était payer tout le passé à chaque envoi.
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.sendMessage(USER, CONVERSATION, MESSAGE, 'Bonjour');

    expect(stubs.repository.findConversation).toHaveBeenCalledWith(
      USER,
      CONVERSATION,
      expect.any(Number),
    );
    const [, , limite] = stubs.repository.findConversation.mock.calls[0] as [
      string,
      string,
      number,
    ];
    expect(limite).toBeGreaterThan(0);
  });

  it('rejouer un message plus ANCIEN que la fenêtre reste un rejeu', async () => {
    // Le piège que la fenêtre introduit. Le rejeu se cherchait dans le fil
    // chargé en mémoire ; borné, celui-ci ne contient plus les vieux
    // messages. Un message hors fenêtre aurait donc été pris pour NEUF : un
    // tour de quota brûlé, le modèle rappelé, puis un échec d'écriture sur
    // un identifiant déjà pris. Le rejeu se cherche par identifiant.
    const stubs = buildStubs();
    const ancien = storedMessage('USER', 'Salut coach.', MESSAGE);
    const reponse = storedMessage('ASSISTANT', 'Salut.', 'reponse-ancienne');
    stubs.repository.findMessageWithReply.mockResolvedValue({ message: ancien, reply: reponse });
    // La fenêtre, elle, ne le contient PAS — c'est tout le propos.
    stubs.repository.findConversation.mockResolvedValue(
      conversationWith([storedMessage('USER', 'Bien plus récent.', 'message-99')]),
    );
    const service = buildService(stubs);

    const reply = await service.sendMessage(USER, CONVERSATION, MESSAGE, 'Salut coach.');

    expect(reply.assistantMessage.id).toBe('reponse-ancienne');
    expect(stubs.quota.consume).not.toHaveBeenCalled();
    expect(stubs.model.reply).not.toHaveBeenCalled();
    expect(stubs.repository.saveUserMessage).not.toHaveBeenCalled();
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
