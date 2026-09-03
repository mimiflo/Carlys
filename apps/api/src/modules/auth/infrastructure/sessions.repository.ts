import { Injectable } from '@nestjs/common';
import {
  type Prisma,
  type RefreshToken,
  RefreshTokenStatus,
  type User,
  type UserSession,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export interface CreateSessionInput {
  userId: string;
  refreshTokenHash: string;
  expiresAt: Date;
  deviceName?: string;
  devicePlatform?: string;
  ipAddress?: string;
  userAgent?: string;
}

export type RefreshTokenWithSession = RefreshToken & {
  session: UserSession & { user: User };
};

/** Accès Prisma des sessions et refresh tokens. */
@Injectable()
export class SessionsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Crée la session et son premier refresh token en une transaction. */
  create(input: CreateSessionInput): Promise<UserSession> {
    return this.prisma.userSession.create({
      data: {
        userId: input.userId,
        deviceName: input.deviceName ?? null,
        devicePlatform: input.devicePlatform ?? null,
        ipAddress: input.ipAddress ?? null,
        userAgent: input.userAgent ?? null,
        expiresAt: input.expiresAt,
        refreshTokens: {
          create: { tokenHash: input.refreshTokenHash, expiresAt: input.expiresAt },
        },
      },
    });
  }

  findRefreshTokenByHash(tokenHash: string): Promise<RefreshTokenWithSession | null> {
    return this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { session: { include: { user: true } } },
    });
  }

  /**
   * Rotation atomique : l'ancien jeton passe à ROTATED, un nouveau jeton
   * ACTIVE est créé et l'expiration de la session glisse.
   */
  async rotateRefreshToken(
    oldTokenId: string,
    sessionId: string,
    newTokenHash: string,
    newExpiresAt: Date,
  ): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      // Rotation conditionnelle : seul le premier des refresh concurrents
      // portant le même jeton gagne — les autres voient count === 0.
      const rotated = await tx.refreshToken.updateMany({
        where: { id: oldTokenId, status: RefreshTokenStatus.ACTIVE },
        data: { status: RefreshTokenStatus.ROTATED, rotatedAt: new Date() },
      });
      if (rotated.count === 0) {
        return false;
      }
      await tx.refreshToken.create({
        data: { sessionId, tokenHash: newTokenHash, expiresAt: newExpiresAt },
      });
      await tx.userSession.update({
        where: { id: sessionId },
        data: { lastUsedAt: new Date(), expiresAt: newExpiresAt },
      });
      return true;
    });
  }

  async revokeSession(sessionId: string, reason: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.userSession.update({
        where: { id: sessionId },
        data: { revokedAt: new Date(), revokedReason: reason },
      }),
      this.prisma.refreshToken.updateMany({
        where: { sessionId, status: RefreshTokenStatus.ACTIVE },
        data: { status: RefreshTokenStatus.REVOKED },
      }),
    ]);
  }

  /**
   * Révoque toutes les sessions actives d'un utilisateur (sauf exclusion).
   *
   * Avec `tx`, la révocation s'inscrit dans une transaction ouverte par
   * l'appelant (la suppression de compte) ; sans, elle ouvre la sienne.
   */
  async revokeAllSessions(
    userId: string,
    reason: string,
    exceptSessionId?: string,
    tx?: Prisma.TransactionClient,
  ): Promise<void> {
    const where = {
      userId,
      revokedAt: null,
      ...(exceptSessionId === undefined ? {} : { id: { not: exceptSessionId } }),
    };
    const revoke = async (client: Prisma.TransactionClient): Promise<void> => {
      await client.refreshToken.updateMany({
        where: { session: where, status: RefreshTokenStatus.ACTIVE },
        data: { status: RefreshTokenStatus.REVOKED },
      });
      await client.userSession.updateMany({
        where,
        data: { revokedAt: new Date(), revokedReason: reason },
      });
    };
    if (tx !== undefined) {
      await revoke(tx);
      return;
    }
    await this.prisma.$transaction(revoke);
  }

  findSessionById(sessionId: string): Promise<UserSession | null> {
    return this.prisma.userSession.findUnique({ where: { id: sessionId } });
  }

  listActiveSessions(userId: string): Promise<UserSession[]> {
    return this.prisma.userSession.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { lastUsedAt: 'desc' },
    });
  }
}
