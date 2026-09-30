import {
  type CoachConversation,
  type CoachConversationSummary,
  type CoachReply,
} from '@carlys/api-contracts';
import { ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import {
  COACH_MODEL_PORT,
  type CoachModelPort,
  CoachProviderUnavailableException,
} from '../domain/coach-model.port';
import { type ConversationWithMessages, CoachRepository } from '../infrastructure/coach.repository';
import { CoachAvailability } from './coach.availability';
import { presentMessage } from './coach.presenter';
import { COACH_TOOLS, CoachTools } from './coach.tools';
import { COACH_SYSTEM_PROMPT, mentorVoiceBriefing } from './coach.prompt';
import { CoachQuota, CoachQuotaExceededError } from './coach.quota';
import { replay } from './coach.replay';
import { HISTORY_LIMIT, buildHistory, extractExerciseIds, titleFrom } from './coach.turn';
import { validateProposal } from './proposal.validator';

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
    private readonly availability: CoachAvailability,
    @Inject(COACH_MODEL_PORT) private readonly model: CoachModelPort,
    @InjectPinoLogger(CoachService.name) private readonly logger: PinoLogger,
  ) {}

  /**
   * LIRE ses propres fils reste ouvert à leur auteur, abonné ou non, coach
   * configuré ou non : ce qu'on a écrit avec le Premium reste consultable
   * (CGU), et les conversations sont conservées « pour que tu puisses les
   * reprendre » (politique de confidentialité). La porte du coach
   * (`CoachAvailability`) ne garde que ce qui coûte ou engage : ouvrir un fil
   * et envoyer un message. La propriété, elle, est vérifiée partout.
   */
  async listConversations(userId: string): Promise<CoachConversationSummary[]> {
    const rows = await this.repository.listConversations(userId, CONVERSATIONS_LIMIT);
    return rows.map((row) => ({
      id: row.id,
      title: row.title,
      messagesCount: row._count.messages,
      updatedAt: row.updatedAt.toISOString(),
    }));
  }

  async createConversation(userId: string, id: string): Promise<CoachConversationSummary> {
    await this.availability.assertAvailable(userId);
    await this.repository.ensureConversation(userId, id);
    const conversation = await this.requireConversation(userId, id);
    return {
      id: conversation.id,
      title: conversation.title,
      messagesCount: conversation.messages.length,
      updatedAt: conversation.updatedAt.toISOString(),
    };
  }

  /** Lecture d'un fil : ouverte à son auteur, comme la liste (voir plus haut). */
  async conversation(userId: string, id: string): Promise<CoachConversation> {
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
    onText?: (delta: string) => void,
  ): Promise<CoachReply> {
    await this.availability.assertAvailable(userId);
    await this.repository.ensureConversation(userId, conversationId);
    // La fenêtre chargée ne sert QUE d'historique pour le modèle, qui est de
    // toute façon plafonné : inutile de relire tout le passé du fil à chaque
    // phrase. `+ 1` pour que le message de ce tour, s'il y figure déjà,
    // n'évince pas un tour utile.
    const conversation = await this.requireConversation(userId, conversationId, HISTORY_LIMIT + 1);

    // UN tour à la fois par question, pris AVANT de chercher le rejeu : un
    // renvoi arrivé pendant que la réponse s'écrit encore (flux coupé, écran
    // rouvert) ne doit ni recompter le quota ni rappeler le modèle, puis
    // archiver deux réponses ; après la réponse, il la trouvera archivée.
    const release = await this.quota.holdTurn(messageId);
    if (release === null) {
      throw new ConflictException('Le coach répond déjà à ce message.');
    }
    try {
      return await this.answer(userId, conversation, messageId, content, onText);
    } finally {
      // Le verrou expire seul : un Redis qui flanche ici ne doit pas masquer
      // la réponse archivée, ni la panne qui a interrompu le tour.
      await release().catch((error: unknown) =>
        this.logger.warn({ err: error, messageId }, 'Verrou de tour non levé'),
      );
    }
  }

  /** Le tour proprement dit, sous le verrou de la question. */
  private async answer(
    userId: string,
    conversation: ConversationWithMessages,
    messageId: string,
    content: string,
    onText: ((delta: string) => void) | undefined,
  ): Promise<CoachReply> {
    const conversationId = conversation.id;
    // Le rejeu se cherche par IDENTIFIANT, pas dans la fenêtre : un message
    // plus ancien qu'elle y serait introuvable, donc pris pour neuf — un tour
    // de quota brûlé, le modèle rappelé, puis un échec d'écriture.
    const deja = await this.repository.findMessageWithReply(conversationId, messageId);
    if (deja === null) {
      // L'identifiant n'est unique que globalement : déjà porté par un AUTRE
      // fil, il n'a rien à faire ici. Vérifié AVANT le compteur (un rejeu
      // invalide ne coûte pas un tour), refusé comme un fil d'autrui : 404.
      await this.assertMessageAddressable(conversationId, messageId);
    } else {
      const replayed = await replay(this.quota, userId, deja.message, deja.reply, content);
      if (replayed !== null) {
        return replayed;
      }
    }

    // La voix du Mentor (profil Carlys + style choisi) aiguille le ton du
    // coach. Chargée AVANT le compteur, et dégradée en silence : un incident
    // sur cette lecture ne doit ni brûler un tour de quota, ni empêcher le
    // coach de répondre.
    const voice = await this.repository
      .voiceOf(userId)
      .catch(() => ({ carlysProfile: null, mentorStyle: null }));

    // Le compteur passe AVANT l'appel : deux envois simultanés ne franchissent
    // jamais le plafond. `now` est gardé pour rendre le message au même jour.
    const now = new Date();
    const remaining = await this.quota.consume(userId, now);
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
    const output = await this.model
      .reply({
        system: COACH_SYSTEM_PROMPT,
        // Après la césure de cache : le préfixe partagé reste identique pour
        // tous les utilisateurs, briefing ou pas.
        systemPerUser: mentorVoiceBriefing(voice),
        tools: COACH_TOOLS,
        history,
        runTools: (calls) => this.tools.run(userId, calls),
        onText,
      })
      .catch((error: unknown) => {
        if (error instanceof CoachProviderUnavailableException) {
          // « Tour de coach » ne sera pas écrit : les jetons déjà partis le sont ici.
          this.logger.warn(
            { userId, conversationId, ...error.usage, reason: error.message },
            'Tour de coach interrompu',
          );
        }
        // Fournisseur tombé sans rien consommer : le message est rendu.
        return this.quota.refundIfUnavailable(userId, now, error);
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

  /**
   * Lancer une séance proposée dans un fil passé reste possible sans
   * abonnement : la proposition a été faite, elle appartient à son auteur
   * (propriété vérifiée par le dépôt). Seuls l'ouverture d'un fil et l'envoi
   * d'un message passent la porte du coach.
   */
  async acceptProposal(userId: string, proposalId: string, sessionId: string): Promise<void> {
    const marked = await this.repository.markProposalAccepted(userId, proposalId, sessionId);
    if (!marked) {
      throw new NotFoundException('Proposition introuvable.');
    }
  }

  async remainingToday(userId: string): Promise<number> {
    await this.availability.assertAvailable(userId);
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

  private async requireConversation(
    userId: string,
    id: string,
    messageLimit?: number,
  ): Promise<ConversationWithMessages> {
    const conversation = await this.repository.findConversation(userId, id, messageLimit);
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
