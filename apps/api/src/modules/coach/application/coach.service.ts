import {
  type CoachConversation,
  type CoachConversationSummary,
  type CoachReply,
} from '@carlys/api-contracts';
import {
  ConflictException,
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
import { COACH_MODEL_PORT, type CoachModelPort } from '../domain/coach-model.port';
import {
  type ConversationWithMessages,
  CoachRepository,
  type MessageWithProposal,
} from '../infrastructure/coach.repository';
import { presentMessage } from './coach.presenter';
import { COACH_TOOLS, CoachTools } from './coach.tools';
import { COACH_SYSTEM_PROMPT, carlysProfileBriefing } from './coach.prompt';
import { CoachQuota } from './coach.quota';
import { assistantReplyTo, buildHistory, extractExerciseIds, titleFrom } from './coach.turn';
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
/** Même réponse qu'un fil inconnu : ne pas révéler l'existence d'autrui. */
const CONVERSATION_NOT_FOUND = 'Conversation introuvable.';

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

  /**
   * Un tour complet : on écrit, le coach répond. L'identifiant vient de
   * l'appareil et le même envoi peut repartir (hors-ligne, coupure) : rejouer
   * un message déjà répondu rend la MÊME réponse, sans tour de quota ni appel
   * au modèle ; le même identifiant avec un autre contenu est refusé.
   */
  async sendMessage(
    userId: string,
    conversationId: string,
    messageId: string,
    content: string,
  ): Promise<CoachReply> {
    await this.assertAvailable(userId);
    await this.repository.ensureConversation(userId, conversationId);
    const conversation = await this.requireConversation(userId, conversationId);

    const stored = conversation.messages.find((message) => message.id === messageId);
    if (stored === undefined) {
      // L'identifiant n'est unique que globalement : déjà porté par un AUTRE
      // fil, il n'a rien à faire ici. Vérifié AVANT le compteur (un rejeu
      // invalide ne coûte pas un tour), refusé comme un fil d'autrui : 404.
      await this.assertMessageAddressable(conversationId, messageId);
    } else {
      const replayed = await this.replay(userId, conversation, stored, content);
      if (replayed !== null) {
        return replayed;
      }
    }

    // Le profil Carlys aiguille le ton du coach. Chargé AVANT le compteur, et
    // dégradé en silence : un incident sur cette lecture ne doit ni brûler un
    // tour de quota, ni empêcher le coach de répondre.
    const carlysProfile = await this.repository.carlysProfileOf(userId).catch(() => null);

    // Le compteur passe AVANT l'appel : un échec du fournisseur ne doit pas
    // offrir un tour gratuit à qui insiste.
    const remaining = await this.quota.consume(userId);
    if (remaining === null) {
      throw new CoachQuotaExceededError();
    }

    const userMessage = await this.repository.saveUserMessage(conversationId, messageId, content);
    if (userMessage === null) {
      // Course entre la vérification et l'écriture : même refus, rien n'a été écrit.
      throw new NotFoundException(CONVERSATION_NOT_FOUND);
    }

    // Le message de ce tour arrive en dernier, jamais aussi dans l'historique :
    // s'il y figure déjà (tour interrompu, repris ici), il en est retiré.
    const history = buildHistory(
      conversation.messages.filter((message) => message.id !== messageId),
      content,
    );
    const output = await this.model.reply({
      system: COACH_SYSTEM_PROMPT,
      // Après la césure de cache : le préfixe partagé reste identique pour
      // tous les utilisateurs, briefing ou pas.
      systemPerUser: carlysProfileBriefing(carlysProfile),
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
   * Rejeu d'un message déjà écrit dans CE fil. Sa réponse archivée s'il en a
   * une : aucun tour consommé, aucun appel au modèle. `null` si le tour
   * précédent s'est interrompu avant la réponse — il reste à le terminer.
   * Un contenu différent sous le même identifiant est une collision : 409,
   * comme les repas et les séances.
   */
  private async replay(
    userId: string,
    conversation: ConversationWithMessages,
    stored: MessageWithProposal,
    content: string,
  ): Promise<CoachReply | null> {
    if (stored.content !== content) {
      throw new ConflictException('Identifiant de message déjà utilisé.');
    }
    const reply = assistantReplyTo(conversation.messages, stored);
    if (reply === undefined) {
      return null;
    }
    return {
      userMessage: presentMessage(stored),
      assistantMessage: presentMessage(reply),
      remainingToday: await this.quota.remaining(userId),
    };
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
      throw new NotFoundException(CONVERSATION_NOT_FOUND);
    }
    return conversation;
  }

  /** Libre : oui. Porté par un autre fil : 404 opaque. */
  private async assertMessageAddressable(conversationId: string, messageId: string): Promise<void> {
    const owner = await this.repository.conversationIdOfMessage(messageId);
    if (owner !== null && owner !== conversationId) {
      throw new NotFoundException(CONVERSATION_NOT_FOUND);
    }
  }
}
