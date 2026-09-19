import { Injectable } from '@nestjs/common';
import { type Encouragement, type Friendship, FriendRequestStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { friendshipPair } from '../domain/friendship-pair';

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

  /**
   * La ligne d'amitié entre deux personnes, quel que soit le sens. La paire
   * ordonnée est unique en base : une lecture d'index, jamais deux lignes.
   */
  findFriendshipBetween(a: string, b: string): Promise<Friendship | null> {
    return this.prisma.friendship.findUnique({
      where: { userLowId_userHighId: friendshipPair(a, b) },
    });
  }

  /**
   * Crée la demande, ou rend `null` si la paire vient d'être écrite par
   * l'autre côté.
   *
   * C'est la base qui tranche, pas la lecture qui précède : deux personnes
   * qui se demandent en même temps lisent toutes deux « pas de lien » et
   * écrivent toutes deux. L'unicité de la paire refuse la seconde (P2002) ;
   * l'appelant relit alors la ligne gagnante et lui applique ses règles —
   * c'est exactement le cas « demandes croisées = amitié ». Sans ça, la
   * seconde écriture remontait en 500 sur une route qui promet 202.
   */
  async createRequest(requesterId: string, addresseeId: string): Promise<Friendship | null> {
    try {
      return await this.prisma.friendship.create({
        data: { requesterId, addresseeId, ...friendshipPair(requesterId, addresseeId) },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return null;
      }
      throw error;
    }
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

  /**
   * Rouvre une ligne refusée : elle repasse PENDING, datée de maintenant,
   * dans le sens de la personne qui demande (qui peut être l'ancien
   * destinataire, s'il prend contact après avoir refusé).
   */
  reopenRequest(id: string, requesterId: string, addresseeId: string): Promise<Friendship> {
    return this.prisma.friendship.update({
      where: { id },
      data: {
        requesterId,
        addresseeId,
        status: FriendRequestStatus.PENDING,
        respondedAt: null,
        createdAt: new Date(),
      },
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

  /**
   * Débuts des séances terminées des 60 derniers jours (assez pour la série),
   * pour PLUSIEURS comptes à la fois.
   *
   * Une requête par ami était un N+1 sur le chemin le plus fréquenté de
   * l'écran Communauté : `listFriends` les lançait toutes EN PARALLÈLE
   * (`Promise.all`), c'est-à-dire N connexions demandées d'un coup à un pool
   * borné à dix. Quelques amis suffisaient à faire attendre les autres
   * requêtes de la même page — le fil, les demandes, les défis, les blocages,
   * que l'écran réclame en même temps. Une seule requête, quel que soit le
   * nombre d'amis.
   *
   * Rend une carte `userId → débuts`, ordonnée par compte. Un compte sans
   * séance n'y figure pas : l'appelant lit un tableau vide, pas `undefined`.
   */
  async completedSessionStartsByUser(userIds: string[], from: Date): Promise<Map<string, Date[]>> {
    const parCompte = new Map<string, Date[]>();
    if (userIds.length === 0) {
      return parCompte;
    }
    const sessions = await this.prisma.workoutSession.findMany({
      where: {
        userId: { in: userIds },
        status: 'COMPLETED',
        deletedAt: null,
        startedAt: { gte: from },
      },
      select: { userId: true, startedAt: true },
    });
    for (const session of sessions) {
      const deja = parCompte.get(session.userId);
      if (deja === undefined) {
        parCompte.set(session.userId, [session.startedAt]);
      } else {
        deja.push(session.startedAt);
      }
    }
    return parCompte;
  }

  // ── Fil d'encouragements ────────────────────────────────────────────────

  /** Fil reçu, sans les expéditeurs à taire (personnes bloquées). */
  listEncouragements(
    userId: string,
    limit: number,
    excludedSenderIds: string[],
  ): Promise<EncouragementRow[]> {
    return this.prisma.encouragement.findMany({
      where: {
        recipientId: userId,
        ...(excludedSenderIds.length === 0 ? {} : { senderId: { notIn: excludedSenderIds } }),
      },
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
