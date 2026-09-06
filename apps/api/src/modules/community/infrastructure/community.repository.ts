import { Injectable } from '@nestjs/common';
import { type Encouragement, type Friendship, FriendRequestStatus } from '@prisma/client';
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

/** Amitiés, encouragements, code ami et préférence de partage. */
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

  /** Nom d'affichage pour les notifications — jamais l'e-mail. */
  async displayNameOf(userId: string): Promise<string> {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { displayName: true },
    });
    return profile?.displayName ?? 'Membre Carlys';
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
        status: 'COMPLETED',
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

  // ── Code ami ────────────────────────────────────────────────────────────

  /** Résout un code ami (forme canonique) vers son porteur actif. */
  findUserByFriendCode(
    friendCode: string,
  ): Promise<{ id: string; profile: { displayName: string } | null } | null> {
    return this.prisma.user.findFirst({
      where: { friendCode, status: 'ACTIVE', deletedAt: null },
      select: { id: true, profile: { select: { displayName: true } } },
    });
  }

  async friendCodeOf(userId: string): Promise<string> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { friendCode: true },
    });
    return user.friendCode;
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
