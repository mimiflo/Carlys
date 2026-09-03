import { Injectable } from '@nestjs/common';
import { type CarlysProfile, CoachMessageRole, type Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type ValidatedProposal } from '../application/proposal.validator';

/** Fil avec ses messages et les propositions rattachées. */
export type ConversationWithMessages = Prisma.CoachConversationGetPayload<{
  include: {
    messages: {
      include: { proposal: { include: { items: true } } };
    };
  };
}>;

export type MessageWithProposal = Prisma.CoachMessageGetPayload<{
  include: { proposal: { include: { items: true } } };
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

  async findConversation(userId: string, id: string): Promise<ConversationWithMessages | null> {
    return this.prisma.coachConversation.findFirst({
      where: { id, userId, deletedAt: null },
      include: {
        messages: {
          orderBy: { createdAt: 'asc' },
          include: {
            proposal: {
              include: {
                items: { orderBy: [{ exercisePosition: 'asc' }, { setPosition: 'asc' }] },
              },
            },
          },
        },
      },
    });
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
      include: { proposal: { include: { items: true } } },
    });
    return message.conversationId === conversationId ? message : null;
  }

  /**
   * Réponse du coach, et sa proposition s'il en a formulé une. Écrites dans
   * une seule transaction : une proposition orpheline n'aurait aucun sens.
   */
  async saveAssistantMessage(input: {
    conversationId: string;
    id: string;
    content: string;
    inputTokens: number;
    outputTokens: number;
    proposal: (ValidatedProposal & { id: string; itemIds: string[] }) | null;
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

      // `updatedAt` du fil remonte : la liste est ordonnée par activité.
      await tx.coachConversation.update({
        where: { id: input.conversationId },
        data: input.title === null ? {} : { title: input.title },
      });

      return tx.coachMessage.findUniqueOrThrow({
        where: { id: message.id },
        include: { proposal: { include: { items: true } } },
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
  async carlysProfileOf(userId: string): Promise<CarlysProfile | null> {
    const row = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { carlysProfile: true },
    });
    return row?.carlysProfile ?? null;
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
}
