import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import {
  CoachProviderUnavailableException,
  type CoachTurnInput,
  type CoachTurnOutput,
} from '../domain/coach-model.port';
import { type ProgramsService } from '../../programs/application/programs.service';
import { type UsersService } from '../../users/application/users.service';
import { type CoachGate } from '../infrastructure/coach-gate';
import { type CoachGenerationRepository } from '../infrastructure/coach-generation.repository';
import { type CoachMetrics } from '../infrastructure/coach-metrics';
import { type CoachRepository } from '../infrastructure/coach.repository';
import { CoachContextBuilder } from './coach-context.builder';
import { CoachAdmissions } from './coach-admissions';
import { CoachGateway } from './coach-gateway';
import { type CoachMemory } from './coach-memory';
import { CoachTurnRunner } from './coach-turn.runner';
import { type CoachQuota } from './coach.quota';
import { CoachAvailability } from './coach.availability';
import { CoachService } from './coach.service';
import { type CoachTools } from './coach.tools';

const USER = 'utilisateur-1';
const CONVERSATION = 'fil-1';
const OTHER_CONVERSATION = 'fil-d-autrui';
const MESSAGE = 'message-1';

interface Stubs {
  tools: { run: jest.Mock };
  repository: {
    ensureConversation: jest.Mock;
    findConversation: jest.Mock;
    listConversations: jest.Mock;
    voiceOf: jest.Mock;
    findMessageWithReply: jest.Mock;
    conversationIdOfMessage: jest.Mock;
    saveUserMessage: jest.Mock;
    saveAssistantMessage: jest.Mock;
    catalogueNames: jest.Mock;
  };
  quota: {
    consume: jest.Mock;
    remaining: jest.Mock;
    refundIfUnavailable: jest.Mock;
    holdTurn: jest.Mock;
    withinRate: jest.Mock;
  };
  gate: { enter: jest.Mock; poll: jest.Mock; leave: jest.Mock; renew: jest.Mock };
  model: { reply: jest.Mock<Promise<CoachTurnOutput>, [CoachTurnInput]> };
  logger: { info: jest.Mock; warn: jest.Mock };
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
    programProposal: null,
  };
}

function conversationWith(messages: ReturnType<typeof storedMessage>[]) {
  return {
    id: CONVERSATION,
    userId: USER,
    title: null,
    summary: null,
    summaryThrough: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    deletedAt: null,
    messages,
  };
}

function buildStubs(): Stubs {
  return {
    tools: { run: jest.fn().mockResolvedValue([]) },
    repository: {
      ensureConversation: jest.fn().mockResolvedValue(undefined),
      findConversation: jest.fn().mockResolvedValue(conversationWith([])),
      listConversations: jest.fn().mockResolvedValue([]),
      voiceOf: jest.fn().mockResolvedValue({ carlysProfile: null, mentorStyle: null }),
      findMessageWithReply: jest.fn().mockResolvedValue(null),
      conversationIdOfMessage: jest.fn().mockResolvedValue(null),
      saveUserMessage: jest.fn().mockResolvedValue(storedMessage('USER', 'Salut coach.', MESSAGE)),
      saveAssistantMessage: jest.fn().mockResolvedValue(storedMessage('ASSISTANT', 'Salut.')),
      catalogueNames: jest.fn().mockResolvedValue(new Map()),
    },
    quota: {
      consume: jest.fn().mockResolvedValue(29),
      remaining: jest.fn().mockResolvedValue(29),
      // Comme le vrai : l'erreur repart toujours.
      refundIfUnavailable: jest.fn((_user: string, _now: Date, error: Error) =>
        Promise.reject(error),
      ),
      holdTurn: jest.fn().mockResolvedValue(jest.fn().mockResolvedValue(undefined)),
      withinRate: jest.fn().mockResolvedValue(true),
    },
    // La file est libre : une place, un créneau tout de suite.
    gate: {
      enter: jest.fn().mockResolvedValue('ok'),
      poll: jest.fn().mockResolvedValue({ acquired: true }),
      leave: jest.fn().mockResolvedValue(undefined),
      renew: jest.fn().mockResolvedValue(undefined),
    },
    model: {
      reply: jest.fn<Promise<CoachTurnOutput>, [CoachTurnInput]>().mockResolvedValue({
        text: 'Salut.',
        proposal: null,
        usage: { inputTokens: 10, outputTokens: 5, cacheReadTokens: 0 },
        refused: false,
      }),
    },
    logger: { info: jest.fn(), warn: jest.fn() },
  };
}

function buildService(
  stubs: Stubs,
  acces: { abonne: boolean; coachEnabled: boolean } = { abonne: true, coachEnabled: true },
): CoachService {
  const entitlements = {
    entitlementsFor: jest
      .fn()
      .mockResolvedValue({ entitlements: [{ key: 'ai_coaching', isActive: acces.abonne }] }),
  };
  const config = {
    coachEnabled: acces.coachEnabled,
    anthropicApiKey: 'cle-factice-de-test-32-caracteres',
    coachProvider: {},
    coachGateway: {
      workerUrls: [],
      historyMessages: 20,
      maxMessageChars: 2000,
      queueTimeoutMs: 120_000,
      requestTimeoutMs: 180_000,
    },
  };
  // La porte (configuration + droit) est un collaborateur à part : on lui
  // passe les mêmes doubles qu'avant, la règle testée ne change pas.
  const availability = new CoachAvailability(
    entitlements as unknown as EntitlementsService,
    config as unknown as AppConfigService,
  );
  // La passerelle, le contexte et le tour sont les VRAIS : seules leurs
  // bordures (Redis, métriques, base) sont simulées.
  const gauge = { inc: jest.fn(), dec: jest.fn(), observe: jest.fn() };
  const logger = stubs.logger as unknown as PinoLogger;
  const repository = stubs.repository as unknown as CoachRepository;
  const quota = stubs.quota as unknown as CoachQuota;
  const metrics = new Proxy({}, { get: () => gauge }) as unknown as CoachMetrics;
  const gate = stubs.gate as unknown as CoachGate;
  const gateway = new CoachGateway(
    gate,
    {
      queued: jest.fn().mockResolvedValue(undefined),
      started: jest.fn().mockResolvedValue(undefined),
      streaming: jest.fn().mockResolvedValue(undefined),
      ended: jest.fn().mockResolvedValue(undefined),
    } as unknown as CoachGenerationRepository,
    metrics,
    config as unknown as AppConfigService,
    stubs.model,
    logger,
  );
  const admissions = new CoachAdmissions(
    gate,
    quota,
    metrics,
    config as unknown as AppConfigService,
  );
  const context = new CoachContextBuilder(
    repository,
    { training: jest.fn().mockResolvedValue(null) } as unknown as UsersService,
    { activeProgramName: jest.fn().mockResolvedValue(null) } as unknown as ProgramsService,
    config as unknown as AppConfigService,
  );
  const turns = new CoachTurnRunner(
    repository,
    stubs.tools as unknown as CoachTools,
    quota,
    gateway,
    context,
    { refreshLater: jest.fn() } as unknown as CoachMemory,
    logger,
  );
  return new CoachService(repository, quota, availability, admissions, context, turns, logger);
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

  it('une question sur SES données : la lecture part AVANT le modèle, avec son résultat', async () => {
    const stubs = buildStubs();
    stubs.tools.run.mockImplementation((_user: string, calls: { id: string }[]) =>
      Promise.resolve(calls.map((call) => ({ id: call.id, content: '{"squat":80}' }))),
    );

    await buildService(stubs).sendMessage(
      USER,
      CONVERSATION,
      MESSAGE,
      'Quel est mon record au squat ?',
    );

    expect(stubs.tools.run).toHaveBeenCalledWith(USER, [
      { id: 'lecture00', name: 'get_personal_records', input: {} },
    ]);
    expect(stubs.model.reply.mock.calls[0]?.[0].prefetched).toEqual([
      {
        call: { id: 'lecture00', name: 'get_personal_records', input: {} },
        result: { id: 'lecture00', content: '{"squat":80}' },
      },
    ]);
  });

  it('un programme proposé pendant le tour s’archive avec la réponse', async () => {
    const stubs = buildStubs();
    stubs.model.reply.mockImplementation(async (input: CoachTurnInput) => {
      // Un premier essai hors bornes, corrigé dans le même tour.
      await input.runTools([
        { id: 'a', name: 'propose_program', input: { goal: 'STRENGTH', weeklySessions: 9 } },
      ]);
      await input.runTools([
        {
          id: 'b',
          name: 'propose_program',
          input: { goal: 'STRENGTH', weeklySessions: 3, sessionMinutes: 45 },
        },
      ]);
      return {
        text: 'Trois séances de force.',
        proposal: null,
        usage: { inputTokens: 10, outputTokens: 5, cacheReadTokens: 0 },
        refused: false,
      };
    });

    await buildService(stubs).sendMessage(USER, CONVERSATION, MESSAGE, 'Un programme ?');

    const [saved] = stubs.repository.saveAssistantMessage.mock.calls[0] as [
      { programProposal: { id: string; goal: string; weeklySessions: number } | null },
    ];
    expect(saved.programProposal?.id).toEqual(expect.any(String));
    expect(saved.programProposal).toMatchObject({
      goal: 'STRENGTH',
      weeklySessions: 3,
      sessionMinutes: 45,
    });
  });

  it('sa réflexion : chaque lecture et chaque outil, montrés EN DIRECT et archivés, une fois chacun', async () => {
    const stubs = buildStubs();
    stubs.model.reply.mockImplementation((input: CoachTurnInput) => {
      // Le modèle cherche des exercices (deux fois), puis propose une séance.
      input.onToolCalls?.([{ id: 'a', name: 'search_exercises', input: {} }]);
      input.onToolCalls?.([
        { id: 'b', name: 'search_exercises', input: {} },
        { id: 'c', name: 'propose_session', input: {} },
      ]);
      return Promise.resolve({
        text: 'Voici ta séance.',
        proposal: null,
        usage: { inputTokens: 10, outputTokens: 5, cacheReadTokens: 0 },
        refused: false,
      });
    });
    const shown: string[] = [];

    await buildService(stubs).sendMessage(
      USER,
      CONVERSATION,
      MESSAGE,
      'Mon record, et une séance ?',
      {
        onStep: (label) => shown.push(label),
      },
    );

    const steps = ['Je regarde tes records', 'Je cherche des exercices', 'Je prépare ta séance'];
    expect(shown).toEqual(steps);
    const [saved] = stubs.repository.saveAssistantMessage.mock.calls[0] as [{ steps: string[] }];
    // Aucune séance n'a survécu à la validation : son « Je prépare… » ne
    // s'archive pas, alors qu'il a été montré pendant qu'il se faisait.
    expect(saved.steps).toEqual(steps.slice(0, 2));
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

  it('fournisseur tombé (503) : le 503 repart, et le message est rendu au jour où il a été compté', async () => {
    const stubs = buildStubs();
    const panne = new ServiceUnavailableException('Coach : le fournisseur a répondu 503.');
    stubs.model.reply.mockRejectedValue(panne);
    const service = buildService(stubs);

    await expect(service.sendMessage(USER, CONVERSATION, MESSAGE, 'Bonjour')).rejects.toBe(panne);

    const [, consumedAt] = stubs.quota.consume.mock.calls[0] as [string, Date];
    expect(consumedAt).toBeInstanceOf(Date);
    expect(stubs.quota.refundIfUnavailable).toHaveBeenCalledWith(USER, consumedAt, panne);
    expect(stubs.repository.saveAssistantMessage).not.toHaveBeenCalled();
  });

  it('tour interrompu : ses jetons déjà consommés sont journalisés, jamais le contenu', async () => {
    // Sans cette ligne, un tour qui a vidé le volume du fournisseur avant de
    // tomber n'apparaîtrait nulle part : « Tour de coach » n'est pas écrit.
    const stubs = buildStubs();
    const panne = new CoachProviderUnavailableException('Coach : le fournisseur a répondu 429.', {
      inputTokens: 9000,
      outputTokens: 1800,
      cacheReadTokens: 0,
    });
    stubs.model.reply.mockRejectedValue(panne);
    const service = buildService(stubs);

    await expect(
      service.sendMessage(USER, CONVERSATION, MESSAGE, 'J’ai mal au genou'),
    ).rejects.toBe(panne);

    expect(stubs.logger.warn).toHaveBeenCalledWith(
      {
        userId: USER,
        conversationId: CONVERSATION,
        inputTokens: 9000,
        outputTokens: 1800,
        cacheReadTokens: 0,
        reason: 'Coach : le fournisseur a répondu 429.',
      },
      'Tour de coach interrompu',
    );
    expect(JSON.stringify(stubs.logger.warn.mock.calls)).not.toContain('genou');
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

/**
 * LIRE ses fils reste ouvert à leur auteur : ce qui a été écrit avec le
 * Premium reste consultable (CGU), sans abonnement et même coach coupé.
 * Seuls l'ouverture d'un fil et l'envoi d'un message passent la porte.
 */
describe('CoachService.sendMessage — un tour à la fois, au fil de l’écriture', () => {
  it('une réponse déjà en cours pour cette question : 409, ni quota, ni modèle, ni écriture', async () => {
    const stubs = buildStubs();
    stubs.quota.holdTurn.mockResolvedValue(null);

    await expect(
      buildService(stubs).sendMessage(USER, CONVERSATION, MESSAGE, 'Salut coach.'),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(stubs.quota.consume).not.toHaveBeenCalled();
    expect(stubs.model.reply).not.toHaveBeenCalled();
    expect(stubs.repository.saveUserMessage).not.toHaveBeenCalled();
  });

  it('le verrou est pris AVANT de chercher le rejeu : un renvoi tardif trouve la réponse archivée', async () => {
    const stubs = buildStubs();

    await buildService(stubs).sendMessage(USER, CONVERSATION, MESSAGE, 'Salut coach.');

    const [verrou] = stubs.quota.holdTurn.mock.invocationCallOrder;
    const [rejeu] = stubs.repository.findMessageWithReply.mock.invocationCallOrder;
    expect(verrou).toBeLessThan(rejeu ?? 0);
  });

  it('un verrou qui ne se lève pas ne masque pas la réponse', async () => {
    const stubs = buildStubs();
    stubs.quota.holdTurn.mockResolvedValue(jest.fn().mockRejectedValue(new Error('redis')));

    const reply = await buildService(stubs).sendMessage(
      USER,
      CONVERSATION,
      MESSAGE,
      'Salut coach.',
    );

    expect(reply.assistantMessage.content).toBe('Salut.');
    expect(stubs.logger.warn).toHaveBeenCalled();
  });

  it('le verrou se lève même quand le fournisseur tombe', async () => {
    const stubs = buildStubs();
    const release = jest.fn().mockResolvedValue(undefined);
    stubs.quota.holdTurn.mockResolvedValue(release);
    stubs.model.reply.mockRejectedValue(new ServiceUnavailableException('panne'));

    await expect(
      buildService(stubs).sendMessage(USER, CONVERSATION, MESSAGE, 'Salut coach.'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(release).toHaveBeenCalledTimes(1);
  });

  it('le texte en cours d’écriture est confié au modèle, qui le rend morceau par morceau', async () => {
    const stubs = buildStubs();
    const onText = jest.fn();

    await buildService(stubs).sendMessage(USER, CONVERSATION, MESSAGE, 'Salut coach.', { onText });

    // La passerelle s'interpose (elle date le premier mot) ; seul le dernier
    // mot, peut-être coupé, attend la suite (« dead… lift » : les noms du
    // catalogue, coach-exercise-names.ts).
    stubs.model.reply.mock.calls[0]?.[0].onText?.('Salut coach, ');
    expect(onText).toHaveBeenCalledWith('Salut coach, ');
  });
});

describe('CoachService — la porte ne garde que ce qui coûte', () => {
  it.each([
    ['ancien abonné (403 à l’envoi)', { abonne: false, coachEnabled: true }, ForbiddenException],
    [
      'coach coupé (503 à l’envoi)',
      { abonne: true, coachEnabled: false },
      ServiceUnavailableException,
    ],
  ])('%s : la liste et le fil se lisent, écrire est refusé', async (_cas, acces, refus) => {
    const stubs = buildStubs();
    stubs.repository.findConversation.mockResolvedValue(
      conversationWith([storedMessage('USER', 'Ma question d’avant.', 'message-1')]),
    );
    const service = buildService(stubs, acces);

    await expect(service.listConversations(USER)).resolves.toEqual([]);
    const fil = await service.conversation(USER, CONVERSATION);
    expect(fil.messages.map((message) => message.content)).toEqual(['Ma question d’avant.']);

    await expect(service.createConversation(USER, CONVERSATION)).rejects.toBeInstanceOf(refus);
    await expect(
      service.sendMessage(USER, CONVERSATION, MESSAGE, 'Encore une question'),
    ).rejects.toBeInstanceOf(refus);
    expect(stubs.model.reply).not.toHaveBeenCalled();
    expect(stubs.quota.consume).not.toHaveBeenCalled();
  });
});
