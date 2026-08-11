import { Injectable } from '@nestjs/common';
import {
  type ChallengeParticipation,
  type CommunityChallenge,
  type Encouragement,
  type Friendship,
  FriendRequestStatus,
  WorkoutSessionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Ami accepté, avec le nécessaire pour l'affichage et la confidentialité. */
export interface FriendRow {
  userId: string;
  displayName: string;
  timezone: string;
  sharesProgress: boolean;
}

export interface EncouragementRow extends Encouragement {
  sender: { profile: { displayName: string } | null };
}

export interface FriendshipWithNames extends Friendship {
  requester: { profile: { displayName: string } | null };
}

export interface ChallengeWithStats extends CommunityChallenge {
  participations: Pick<ChallengeParticipation, 'userId' | 'contribution'>[];
}

@Injectable()
export class CommunityRepository {
  constructor(private readonly prisma: PrismaService) {}

  // ── Amitiés ─────────────────────────────────────────────────────────────

  /** La ligne d'amitié entre deux personnes, quel que soit le sens. */
  findFriendshipBetween(a: string, b: string): Promise<Friendship | null> {
    return this.prisma.friendship.findFirst({
      where: {
        OR: [
          { requesterId: a, addresseeId: b },
          { requesterId: b, addresseeId: a },
        ],
      },
    });
  }

  createRequest(requesterId: string, addresseeId: string): Promise<Friendship> {
    return this.prisma.friendship.create({
      data: { requesterId, addresseeId },
    });
  }

  findRequestById(id: string): Promise<Friendship | null> {
    return this.prisma.friendship.findUnique({ where: { id } });
  }

  setRequestStatus(id: string, status: FriendRequestStatus): Promise<Friendship> {
    return this.prisma.friendship.update({
      where: { id },
      data: { status, respondedAt: new Date() },
    });
  }

  deleteFriendship(id: string): Promise<void> {
    return this.prisma.friendship.delete({ where: { id } }).then(() => undefined);
  }

  /** Demandes REÇUES en attente, avec le nom de l'expéditeur. */
  listReceivedRequests(userId: string): Promise<FriendshipWithNames[]> {
    return this.prisma.friendship.findMany({
      where: { addresseeId: userId, status: FriendRequestStatus.PENDING },
      orderBy: { createdAt: 'desc' },
      include: { requester: { select: { profile: { select: { displayName: true } } } } },
    });
  }

  /** Amis ACCEPTÉS : identité, fuseau et préférence de partage en une passe. */
  async listFriends(userId: string): Promise<FriendRow[]> {
    const friendships = await this.prisma.friendship.findMany({
      where: {
        status: FriendRequestStatus.ACCEPTED,
        OR: [{ requesterId: userId }, { addresseeId: userId }],
      },
      select: { requesterId: true, addresseeId: true },
    });
    const friendIds = friendships.map((f) =>
      f.requesterId === userId ? f.addresseeId : f.requesterId,
    );
    if (friendIds.length === 0) {
      return [];
    }
    const users = await this.prisma.user.findMany({
      where: { id: { in: friendIds }, deletedAt: null },
      select: {
        id: true,
        profile: { select: { displayName: true, timezone: true } },
        communityPreference: { select: { sharesProgress: true } },
      },
    });
    return users.map((user) => ({
      userId: user.id,
      displayName: user.profile?.displayName ?? 'Membre Carlys',
      timezone: user.profile?.timezone ?? 'Europe/Paris',
      // L'absence de préférence vaut « partagé » (défaut du modèle).
      sharesProgress: user.communityPreference?.sharesProgress ?? true,
    }));
  }

  findUserIdByEmail(email: string): Promise<{ id: string } | null> {
    return this.prisma.user.findFirst({
      where: { email, status: 'ACTIVE', deletedAt: null },
      select: { id: true },
    });
  }

  // ── Statistiques partagées ──────────────────────────────────────────────

  /** Débuts des séances terminées des 60 derniers jours (assez pour la série). */
  async completedSessionStarts(userId: string, from: Date): Promise<Date[]> {
    const sessions = await this.prisma.workoutSession.findMany({
      where: {
        userId,
        status: WorkoutSessionStatus.COMPLETED,
        deletedAt: null,
        startedAt: { gte: from },
      },
      select: { startedAt: true },
    });
    return sessions.map((session) => session.startedAt);
  }

  // ── Fil d'encouragements ────────────────────────────────────────────────

  listEncouragements(userId: string, limit: number): Promise<EncouragementRow[]> {
    return this.prisma.encouragement.findMany({
      where: { recipientId: userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: { sender: { select: { profile: { select: { displayName: true } } } } },
    });
  }

  createEncouragement(
    senderId: string,
    recipientId: string,
    message: string,
  ): Promise<Encouragement> {
    return this.prisma.encouragement.create({
      data: { senderId, recipientId, message },
    });
  }

  // ── Défis collectifs ────────────────────────────────────────────────────

  /** Défis dont la fenêtre n'est pas terminée, avec toutes les contributions. */
  listOpenChallenges(now: Date): Promise<ChallengeWithStats[]> {
    return this.prisma.communityChallenge.findMany({
      where: { endsAt: { gte: now } },
      orderBy: { endsAt: 'asc' },
      include: { participations: { select: { userId: true, contribution: true } } },
    });
  }

  findChallengeById(id: string): Promise<CommunityChallenge | null> {
    return this.prisma.communityChallenge.findUnique({ where: { id } });
  }

  /** Rejoindre est idempotent : rejouer la requête ne crée pas de doublon. */
  async joinChallenge(challengeId: string, userId: string): Promise<void> {
    await this.prisma.challengeParticipation.upsert({
      where: { challengeId_userId: { challengeId, userId } },
      create: { challengeId, userId },
      update: {},
    });
  }

  async leaveChallenge(challengeId: string, userId: string): Promise<void> {
    await this.prisma.challengeParticipation.deleteMany({
      where: { challengeId, userId },
    });
  }

  challengeStats(challengeId: string): Promise<ChallengeWithStats | null> {
    return this.prisma.communityChallenge.findUnique({
      where: { id: challengeId },
      include: { participations: { select: { userId: true, contribution: true } } },
    });
  }

  /** +1 sur tous les défis SPORT rejoints dont la fenêtre couvre `at`. */
  async incrementSportContributions(userId: string, at: Date): Promise<void> {
    await this.prisma.challengeParticipation.updateMany({
      where: {
        userId,
        challenge: { kind: 'SPORT', startsAt: { lte: at }, endsAt: { gte: at } },
      },
      data: { contribution: { increment: 1 } },
    });
  }

  // ── Préférence de partage ───────────────────────────────────────────────

  async sharesProgress(userId: string): Promise<boolean> {
    const preference = await this.prisma.communityPreference.findUnique({
      where: { userId },
      select: { sharesProgress: true },
    });
    return preference?.sharesProgress ?? true;
  }

  async setSharesProgress(userId: string, sharesProgress: boolean): Promise<void> {
    await this.prisma.communityPreference.upsert({
      where: { userId },
      create: { userId, sharesProgress },
      update: { sharesProgress },
    });
  }
}
