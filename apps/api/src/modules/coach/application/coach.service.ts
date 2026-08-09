import {
  type CoachConversation,
  type CoachConversationSummary,
  type CoachMessage,
  type CoachReply,
  type CoachSessionProposal,
} from '@carlys/api-contracts';
import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../../config/app-config.service';
import { EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { COACH_MODEL_PORT, type CoachModelPort, type CoachTurn } from '../domain/coach-model.port';
import {
  type ConversationWithMessages,
  CoachRepository,
  type MessageWithProposal,
} from '../infrastructure/coach.repository';
import { COACH_TOOLS, CoachTools } from './coach.tools';
import { COACH_SYSTEM_PROMPT, volatileContext } from './coach.prompt';
import { CoachQuota } from './coach.quota';
import { validateProposal } from './proposal.validator';

/**
 * Plafond quotidien atteint. `HttpException` plutôt qu'une erreur maison : le
 * filtre global la traduit en 429 / RATE_LIMITED sans code d'adaptation.
 */
export class CoachQuotaExceededError extends HttpException {
  constructor() {
    super('Tu as atteint ta limite de messages pour aujourd’hui.', HttpStatus.TOO_MANY_REQUESTS);
  }
}

const REQUIRED_ENTITLEMENT = 'ai_coaching';
const CONVERSATIONS_LIMIT = 30;
/** Tours renvoyés au modèle. Au-delà, la compaction serait nécessaire. */
const HISTORY_LIMIT = 20;
const TITLE_MAX_LENGTH = 60;

/**
 * Orchestration d'un tour de conversation.
 *
 * L'IA propose, l'application exécute : ce service ne laisse au modèle que des
 * outils de LECTURE, valide sa proposition contre le catalogue, et n'écrit
 * jamais de séance — c'est l'utilisateur qui accepte, par le chemin existant.
 */
@Injectable()
export class CoachService {
  constructor(
    private readonly repository: CoachRepository,
    private readonly tools: CoachTools,
    private readonly quota: CoachQuota,
    private readonly entitlements: EntitlementsService,
    private readonly config: AppConfigService,
    @Inject(COACH_MODEL_PORT) private readonly model: CoachModelPort,
    @InjectPinoLogger(CoachService.name) private readonly logger: PinoLogger,
  ) {}

  async listConversations(userId: string): Promise<CoachConversationSummary[]> {
    await this.assertAvailable(userId);
    const rows = await this.repository.listConversations(userId, CONVERSATIONS_LIMIT);
    return rows.map((row) => ({
      id: row.id,
      title: row.title,
      messagesCount: row._count.messages,
      updatedAt: row.updatedAt.toISOString(),
    }));
  }

  async createConversation(userId: string, id: string): Promise<CoachConversationSummary> {
    await this.assertAvailable(userId);
    await this.repository.ensureConversation(userId, id);
    const conversation = await this.requireConversation(userId, id);
    return {
      id: conversation.id,
      title: conversation.title,
      messagesCount: conversation.messages.length,
      updatedAt: conversation.updatedAt.toISOString(),
    };
  }

  async conversation(userId: string, id: string): Promise<CoachConversation> {
    await this.assertAvailable(userId);
    const conversation = await this.requireConversation(userId, id);
    return {
      id: conversation.id,
      title: conversation.title,
      messagesCount: conversation.messages.length,
      updatedAt: conversation.updatedAt.toISOString(),
      messages: conversation.messages.map(presentMessage),
    };
  }

  /** Un tour complet : on écrit, le coach répond. */
  async sendMessage(
    userId: string,
    conversationId: string,
    messageId: string,
    content: string,
  ): Promise<CoachReply> {
    await this.assertAvailable(userId);
    await this.repository.ensureConversation(userId, conversationId);
    const conversation = await this.requireConversation(userId, conversationId);

    // Le compteur passe AVANT l'appel : un échec du fournisseur ne doit pas
    // offrir un tour gratuit à qui insiste.
    const remaining = await this.quota.consume(userId);
    if (remaining === null) {
      throw new CoachQuotaExceededError();
    }

    const userMessage = await this.repository.saveUserMessage(conversationId, messageId, content);

    const history = buildHistory(conversation, content);
    const output = await this.model.reply({
      system: COACH_SYSTEM_PROMPT,
      tools: COACH_TOOLS,
      history,
      runTools: (calls) => this.tools.run(userId, calls),
    });

    const proposal = await this.acceptableProposal(output.proposal);

    this.logger.info(
      {
        userId,
        conversationId,
        inputTokens: output.usage.inputTokens,
        outputTokens: output.usage.outputTokens,
        cacheReadTokens: output.usage.cacheReadTokens,
        proposed: proposal !== null,
        refused: output.refused,
      },
      'Tour de coach',
    );

    const assistantMessage = await this.repository.saveAssistantMessage({
      conversationId,
      id: randomUUID(),
      content: output.text,
      inputTokens: output.usage.inputTokens,
      outputTokens: output.usage.outputTokens,
      proposal:
        proposal === null
          ? null
          : {
              ...proposal,
              id: randomUUID(),
              itemIds: proposal.items.map(() => randomUUID()),
            },
      title: conversation.title ?? titleFrom(content),
    });

    return {
      userMessage: presentMessage(userMessage),
      assistantMessage: presentMessage(assistantMessage),
      remainingToday: remaining,
    };
  }

  async acceptProposal(userId: string, proposalId: string, sessionId: string): Promise<void> {
    await this.assertAvailable(userId);
    const marked = await this.repository.markProposalAccepted(userId, proposalId, sessionId);
    if (!marked) {
      throw new NotFoundException('Proposition introuvable.');
    }
  }

  async remainingToday(userId: string): Promise<number> {
    await this.assertAvailable(userId);
    return this.quota.remaining(userId);
  }

  /**
   * Rejette tout ce qui n'est pas une proposition valide. Un exercice inconnu
   * fait tomber la proposition entière : mieux vaut une réponse sans séance
   * qu'une séance inventée.
   */
  private async acceptableProposal(raw: Record<string, unknown> | null) {
    if (raw === null) {
      return null;
    }
    const ids = extractExerciseIds(raw);
    const catalogue = await this.repository.catalogueNames(ids);
    const validation = validateProposal(raw, catalogue);
    if (!validation.ok) {
      this.logger.warn({ reason: validation.reason }, 'Proposition du coach rejetée');
      return null;
    }
    return validation.proposal;
  }

  /**
   * Le coach est-il disponible pour cet utilisateur ?
   * Coupé globalement ou sans clé → 503. Sans droit → 403. Dans les deux cas,
   * AVANT toute dépense de jeton.
   */
  private async assertAvailable(userId: string): Promise<void> {
    if (!this.config.coachEnabled || this.config.anthropicApiKey === undefined) {
      throw new ServiceUnavailableException('Le coach est momentanément indisponible.');
    }
    const { entitlements } = await this.entitlements.entitlementsFor(userId);
    const granted = entitlements.some(
      (entitlement) => entitlement.key === REQUIRED_ENTITLEMENT && entitlement.isActive,
    );
    if (!granted) {
      throw new ForbiddenException('Le coach est réservé aux abonnés.');
    }
  }

  private async requireConversation(userId: string, id: string): Promise<ConversationWithMessages> {
    const conversation = await this.repository.findConversation(userId, id);
    if (conversation === null) {
      throw new NotFoundException('Conversation introuvable.');
    }
    return conversation;
  }
}

/**
 * Historique envoyé au modèle. Le rappel de date est collé au DERNIER message
 * — donc après la césure de cache, jamais dans le préfixe stable.
 */
function buildHistory(
  conversation: ConversationWithMessages,
  content: string,
  now: Date = new Date(),
): CoachTurn[] {
  const previous = conversation.messages.slice(-HISTORY_LIMIT).map((message): CoachTurn => ({
    role: message.role === 'USER' ? 'user' : 'assistant',
    content: message.content,
  }));
  return [...previous, { role: 'user', content: `${volatileContext(now)}\n${content}` }];
}

/** Identifiants cités par la proposition, pour n'interroger que ceux-là. */
function extractExerciseIds(raw: Record<string, unknown>): string[] {
  if (!Array.isArray(raw.items)) {
    return [];
  }
  const ids = new Set<string>();
  for (const entry of raw.items) {
    if (typeof entry === 'object' && entry !== null) {
      const id = (entry as Record<string, unknown>).exerciseId;
      if (typeof id === 'string') {
        ids.add(id);
      }
    }
  }
  return [...ids];
}

/** Titre du fil : la première question, tronquée. */
function titleFrom(content: string): string {
  const trimmed = content.trim();
  return trimmed.length <= TITLE_MAX_LENGTH
    ? trimmed
    : `${trimmed.slice(0, TITLE_MAX_LENGTH - 1)}…`;
}

function presentMessage(message: MessageWithProposal): CoachMessage {
  return {
    id: message.id,
    role: message.role,
    content: message.content,
    proposal: message.proposal === null ? null : presentProposal(message.proposal),
    createdAt: message.createdAt.toISOString(),
  };
}

function presentProposal(
  proposal: NonNullable<MessageWithProposal['proposal']>,
): CoachSessionProposal {
  return {
    id: proposal.id,
    name: proposal.name,
    estimatedMinutes: proposal.estimatedMinutes,
    sourceTemplateId: proposal.sourceTemplateId,
    acceptedSessionId: proposal.acceptedSessionId,
    items: proposal.items.map((item) => ({
      id: item.id,
      exercisePosition: item.exercisePosition,
      exerciseId: item.exerciseId,
      exerciseName: item.exerciseName,
      setPosition: item.setPosition,
      kind: item.kind,
      targetReps: item.targetReps,
      targetWeightKg: item.targetWeightKg === null ? null : Number(item.targetWeightKg),
      restSeconds: item.restSeconds,
    })),
  };
}
