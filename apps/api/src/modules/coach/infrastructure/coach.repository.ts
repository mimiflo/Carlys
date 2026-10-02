import { Injectable } from '@nestjs/common';
import {
  type CarlysProfile,
  CoachMessageRole,
  type MentorStyle,
  type Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type ValidatedProgramProposal } from '../application/program-proposal.validator';
import { type ValidatedProposal } from '../application/proposal.validator';

/**
 * Les propositions d'un message — séance (séries dans l'ordre de l'écran) et
 * programme. UNE définition pour toutes les lectures : un ajout ici ne peut
 * plus manquer à l'une d'elles.
 * `satisfies` plutôt qu'une annotation : l'annotation effacerait le type
 * littéral, et Prisma ne saurait plus que `items` est chargé.
 */
const PROPOSITION_ORDONNEE = {
  proposal: {
    include: { items: { orderBy: [{ exercisePosition: 'asc' }, { setPosition: 'asc' }] } },
  },
  programProposal: true,
} satisfies Prisma.CoachMessageInclude;

/** Fil avec ses messages et les propositions rattachées. */
export type ConversationWithMessages = Prisma.CoachConversationGetPayload<{
  include: { messages: { include: typeof PROPOSITION_ORDONNEE } };
}>;

export type MessageWithProposal = Prisma.CoachMessageGetPayload<{
  include: typeof PROPOSITION_ORDONNEE;
}>;

/** Accès Prisma du coach — et de lui seul. */
@Injectable()
export class CoachRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Crée le fil s'il n'existe pas. L'identifiant vient de l'appareil : deux
   * envois du même fil ne doivent pas produire deux lignes ni une erreur.
   */
  async ensureConversation(userId: string, id: string): Promise<void> {
    await this.prisma.coachConversation.upsert({
      where: { id },
      create: { id, userId },
      update: {},
    });
  }

  /**
   * Un fil et ses messages, du plus ancien au plus récent.
   *
   * `messageLimit` ne garde que les N DERNIERS. Le chemin chaud — envoyer un
   * message — n'a besoin que de ceux-là : l'historique transmis au modèle est
   * plafonné à vingt tours, et le fil, lui, n'a aucun plafond. Relire des
   * centaines de messages, leurs propositions et les séries de chaque
   * proposition pour en garder vingt, à chaque envoi, c'était payer le passé
   * entier à chaque phrase.
   *
   * Sans limite, tout le fil : c'est ce que l'écran de conversation demande,
   * et il a raison de le demander.
   */
  async findConversation(
    userId: string,
    id: string,
    messageLimit?: number,
  ): Promise<ConversationWithMessages | null> {
    const conversation = await this.prisma.coachConversation.findFirst({
      where: { id, userId, deletedAt: null },
      include: {
        messages: {
          // Les N DERNIERS se prennent en ordre décroissant puis se
          // remettent à l'endroit — `take` sur un tri croissant rendrait les
          // N premiers, c'est-à-dire le début du fil.
          orderBy: { createdAt: messageLimit === undefined ? 'asc' : 'desc' },
          ...(messageLimit === undefined ? {} : { take: messageLimit }),
          include: PROPOSITION_ORDONNEE,
        },
      },
    });
    if (conversation !== null && messageLimit !== undefined) {
      conversation.messages.reverse();
    }
    return conversation;
  }

  /**
   * Un message de CE fil, avec la réponse d'assistant qui le suit
   * immédiatement — ou `null` si l'identifiant n'appartient pas à ce fil.
   *
   * Le rejeu se cherchait auparavant dans le fil chargé en mémoire. Depuis
   * que ce chargement est borné, un message plus ancien que la fenêtre n'y
   * serait plus trouvé : le service le prendrait pour un message NEUF,
   * brûlerait un tour de quota, rappellerait le modèle, puis échouerait à
   * l'écrire (identifiant déjà pris). Chercher par identifiant, sur une clé
   * primaire, coûte moins cher que la fenêtre qu'on vient d'économiser et ne
   * dépend plus de sa taille.
   */
  async findMessageWithReply(
    conversationId: string,
    messageId: string,
  ): Promise<{ message: MessageWithProposal; reply: MessageWithProposal | null } | null> {
    const message = await this.prisma.coachMessage.findFirst({
      where: { id: messageId, conversationId },
      include: PROPOSITION_ORDONNEE,
    });
    if (message === null) {
      return null;
    }
    // « Immédiatement après » se lit sur la date, comme le faisait le
    // parcours du tableau : le premier message postérieur, et seulement s'il
    // vient de l'assistant.
    const suivant = await this.prisma.coachMessage.findFirst({
      where: { conversationId, createdAt: { gte: message.createdAt }, id: { not: message.id } },
      orderBy: { createdAt: 'asc' },
      include: PROPOSITION_ORDONNEE,
    });
    return {
      message,
      reply: suivant !== null && suivant.role === CoachMessageRole.ASSISTANT ? suivant : null,
    };
  }

  async listConversations(
    userId: string,
    limit: number,
  ): Promise<
    { id: string; title: string | null; updatedAt: Date; _count: { messages: number } }[]
  > {
    return this.prisma.coachConversation.findMany({
      where: { userId, deletedAt: null },
      orderBy: { updatedAt: 'desc' },
      take: limit,
      select: {
        id: true,
        title: true,
        updatedAt: true,
        _count: { select: { messages: true } },
      },
    });
  }

  /**
   * À quel fil appartient déjà cet identifiant de message ? `null` s'il est
   * libre. L'identifiant vient de l'appareil et n'est unique que GLOBALEMENT
   * (clé primaire), pas par fil : c'est ce qui rend ce contrôle nécessaire.
   */
  async conversationIdOfMessage(id: string): Promise<string | null> {
    const row = await this.prisma.coachMessage.findUnique({
      where: { id },
      select: { conversationId: true },
    });
    return row?.conversationId ?? null;
  }

  /**
   * Message de l'utilisateur, adressé par (fil, identifiant) : rejouer le même
   * identifiant dans le même fil ne double pas. Un identifiant déjà porté par
   * un AUTRE fil n'est ni réécrit ni relu : `null`, et rien n'a été écrit
   * (la branche `update` est vide).
   */
  async saveUserMessage(
    conversationId: string,
    id: string,
    content: string,
  ): Promise<MessageWithProposal | null> {
    const message = await this.prisma.coachMessage.upsert({
      where: { id },
      create: { id, conversationId, role: CoachMessageRole.USER, content },
      update: {},
      include: PROPOSITION_ORDONNEE,
    });
    return message.conversationId === conversationId ? message : null;
  }

  /**
   * Réponse du coach, et ses propositions s'il en a formulé. Écrites dans
   * une seule transaction : une proposition orpheline n'aurait aucun sens.
   */
  async saveAssistantMessage(input: {
    conversationId: string;
    id: string;
    content: string;
    inputTokens: number;
    outputTokens: number;
    proposal: (ValidatedProposal & { id: string; itemIds: string[] }) | null;
    programProposal: (ValidatedProgramProposal & { id: string }) | null;
    /** Les étapes de sa réflexion (coach-steps.ts). */
    steps: string[];
    title: string | null;
  }): Promise<MessageWithProposal> {
    return this.prisma.$transaction(async (tx) => {
      const message = await tx.coachMessage.create({
        data: {
          id: input.id,
          conversationId: input.conversationId,
          role: CoachMessageRole.ASSISTANT,
          content: input.content,
          inputTokens: input.inputTokens,
          outputTokens: input.outputTokens,
          steps: input.steps,
        },
      });

      if (input.proposal !== null) {
        await tx.coachSessionProposal.create({
          data: {
            id: input.proposal.id,
            messageId: message.id,
            name: input.proposal.name,
            estimatedMinutes: input.proposal.estimatedMinutes,
            items: {
              create: input.proposal.items.map((item, index) => ({
                id: input.proposal!.itemIds[index]!,
                exercisePosition: item.exercisePosition,
                exerciseId: item.exerciseId,
                exerciseName: item.exerciseName,
                setPosition: item.setPosition,
                kind: item.kind,
                targetReps: item.targetReps,
                targetWeightKg: item.targetWeightKg,
                restSeconds: item.restSeconds,
              })),
            },
          },
        });
      }

      if (input.programProposal !== null) {
        await tx.coachProgramProposal.create({
          data: { ...input.programProposal, messageId: message.id },
        });
      }

      // `updatedAt` du fil remonte : la liste est ordonnée par activité.
      await tx.coachConversation.update({
        where: { id: input.conversationId },
        data: input.title === null ? {} : { title: input.title },
      });

      return tx.coachMessage.findUniqueOrThrow({
        where: { id: message.id },
        include: PROPOSITION_ORDONNEE,
      });
    });
  }

  /**
   * Profil Carlys de l'utilisateur — une colonne indexée, rien d'autre.
   *
   * Lecture Prisma directe plutôt que par le module users : même précédent
   * que `NutritionRepository.findProfile`, pour une préférence déclarée qui
   * aiguille le ton du coach à chaque tour.
   */
  /**
   * La voix complète du Mentor en UNE lecture : profil Carlys et style,
   * les deux axes que le briefing compose. Une seule requête plutôt que
   * deux : ils vivent sur la même ligne de profil.
   */
  async voiceOf(userId: string): Promise<{
    carlysProfile: CarlysProfile | null;
    mentorStyle: MentorStyle | null;
  }> {
    const row = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { carlysProfile: true, mentorStyle: true },
    });
    return {
      carlysProfile: row?.carlysProfile ?? null,
      mentorStyle: row?.mentorStyle ?? null,
    };
  }

  /**
   * Noms des exercices réels, par identifiant. C'est la table contre laquelle
   * toute proposition est confrontée : ce qui n'y figure pas n'existe pas.
   */
  async catalogueNames(exerciseIds: string[]): Promise<Map<string, string>> {
    if (exerciseIds.length === 0) {
      return new Map();
    }
    const rows = await this.prisma.exercise.findMany({
      where: { id: { in: exerciseIds }, isPublished: true },
      select: { id: true, name: true },
    });
    return new Map(rows.map((row) => [row.id, row.name]));
  }

  /** Marque la proposition comme acceptée, et par quelle séance. */
  async markProposalAccepted(
    userId: string,
    proposalId: string,
    sessionId: string,
  ): Promise<boolean> {
    const result = await this.prisma.coachSessionProposal.updateMany({
      where: {
        id: proposalId,
        message: { conversation: { userId, deletedAt: null } },
      },
      data: { acceptedSessionId: sessionId },
    });
    return result.count > 0;
  }

  /** Marque le programme proposé comme accepté, et par quel programme. */
  async markProgramProposalAccepted(
    userId: string,
    proposalId: string,
    programId: string,
  ): Promise<boolean> {
    const result = await this.prisma.coachProgramProposal.updateMany({
      where: {
        id: proposalId,
        message: { conversation: { userId, deletedAt: null } },
      },
      data: { acceptedProgramId: programId },
    });
    return result.count > 0;
  }

  /**
   * Messages sortis de la fenêtre relue (`keepLast` derniers) et pas encore
   * résumés, du plus ancien au plus récent, `batch` au plus : un long fil se
   * rattrape en plusieurs passes, sans jamais un prompt démesuré.
   */
  async memoryBacklog(
    conversationId: string,
    keepLast: number,
    batch: number,
  ): Promise<MemoryBacklog | null> {
    const conversation = await this.prisma.coachConversation.findUnique({
      where: { id: conversationId },
      select: { summary: true, summaryThrough: true },
    });
    if (conversation === null) return null;
    const boundary = await this.prisma.coachMessage.findFirst({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      skip: keepLast - 1,
      select: { createdAt: true },
    });
    if (boundary === null) return { summary: conversation.summary, messages: [] };
    const messages = await this.prisma.coachMessage.findMany({
      where: {
        conversationId,
        createdAt: {
          lt: boundary.createdAt,
          ...(conversation.summaryThrough ? { gt: conversation.summaryThrough } : {}),
        },
      },
      orderBy: { createdAt: 'asc' },
      take: batch,
      select: { role: true, content: true, createdAt: true },
    });
    return { summary: conversation.summary, messages };
  }

  /** La mémoire réécrite — jamais par-dessus une mémoire plus récente. */
  async saveSummary(conversationId: string, summary: string, through: Date): Promise<void> {
    await this.prisma.coachConversation.updateMany({
      where: {
        id: conversationId,
        OR: [{ summaryThrough: null }, { summaryThrough: { lt: through } }],
      },
      data: { summary, summaryThrough: through },
    });
  }
}

export interface MemoryBacklog {
  summary: string | null;
  messages: { role: 'USER' | 'ASSISTANT'; content: string; createdAt: Date }[];
}
