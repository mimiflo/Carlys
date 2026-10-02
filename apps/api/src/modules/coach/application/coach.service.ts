import {
  type CoachConversation,
  type CoachConversationSummary,
  type CoachReply,
} from '@carlys/api-contracts';
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { type ConversationWithMessages, CoachRepository } from '../infrastructure/coach.repository';
import { CoachContextBuilder } from './coach-context.builder';
import { CoachAdmissions } from './coach-admissions';
import { type CoachStream, CoachTurnRunner } from './coach-turn.runner';
import { CoachAvailability } from './coach.availability';
import { presentMessage } from './coach.presenter';
import { CoachQuota, CoachQuotaExceededError } from './coach.quota';

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
    private readonly quota: CoachQuota,
    private readonly availability: CoachAvailability,
    private readonly admissions: CoachAdmissions,
    private readonly context: CoachContextBuilder,
    private readonly turns: CoachTurnRunner,
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
    stream: CoachStream = {},
  ): Promise<CoachReply> {
    await this.availability.assertAvailable(userId);
    await this.repository.ensureConversation(userId, conversationId);
    // La fenêtre chargée ne sert QUE d'historique pour le modèle, qui est de
    // toute façon plafonné : inutile de relire tout le passé du fil à chaque
    // phrase. `+ 1` pour que le message de ce tour, s'il y figure déjà,
    // n'évince pas un tour utile.
    const conversation = await this.requireConversation(
      userId,
      conversationId,
      this.context.window,
    );

    // UN tour à la fois par question, pris AVANT de chercher le rejeu : un
    // renvoi arrivé pendant que la réponse s'écrit encore (flux coupé, écran
    // rouvert) ne doit ni recompter le quota ni rappeler le modèle, puis
    // archiver deux réponses ; après la réponse, il la trouvera archivée.
    const release = await this.quota.holdTurn(messageId);
    if (release === null) {
      throw new ConflictException('Le coach répond déjà à ce message.');
    }
    try {
      return await this.answer(userId, conversation, messageId, content, stream);
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
    stream: CoachStream,
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
      // Rejeu d'un message déjà écrit dans CE fil : sa réponse archivée s'il
      // en a une, sans tour consommé ni appel au modèle ; sans réponse (tour
      // interrompu), il reste à le terminer. Un autre contenu sous le même
      // identifiant est une collision : 409, comme les repas et les séances.
      if (deja.message.content !== content) {
        throw new ConflictException('Identifiant de message déjà utilisé.');
      }
      if (deja.reply !== null) {
        return {
          userMessage: presentMessage(deja.message),
          assistantMessage: presentMessage(deja.reply),
          remainingToday: await this.quota.remaining(userId),
        };
      }
    }

    // La passerelle refuse tôt, sans rien consommer : taille, rythme, une
    // génération par personne, file pleine (ADR 0013). La place se rend
    // quoi qu'il arrive.
    // Plafond du jour déjà atteint : 429 tout de suite, plutôt qu'une place
    // dans la file pour rien. Le décompte, lui, se fait après la file.
    if ((await this.quota.remaining(userId)) === 0) {
      throw new CoachQuotaExceededError();
    }
    const admission = await this.admissions.admit(userId, conversationId, messageId, content);
    try {
      return await this.turns.run(userId, conversation, admission, content, stream);
    } finally {
      await admission
        .release()
        .catch((error: unknown) =>
          this.logger.warn({ err: error, messageId }, 'Place de la passerelle non rendue'),
        );
    }
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

  /** Même règle que pour une séance : le programme proposé appartient à son auteur. */
  async acceptProgramProposal(userId: string, proposalId: string, programId: string) {
    if (!(await this.repository.markProgramProposalAccepted(userId, proposalId, programId))) {
      throw new NotFoundException('Proposition introuvable.');
    }
  }

  async remainingToday(userId: string): Promise<number> {
    await this.availability.assertAvailable(userId);
    return this.quota.remaining(userId);
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
