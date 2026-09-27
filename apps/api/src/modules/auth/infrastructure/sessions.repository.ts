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

  /**
   * Révoque une session : ses refresh tokens meurent, et ses JETONS PUSH
   * sont supprimés dans la même transaction — un appareil déconnecté à
   * distance (ou dont le refresh token a été rejoué) ne reçoit plus rien sur
   * son écran verrouillé. Les jetons antérieurs au rattachement
   * (`sessionId` nul) du même compte tombent aussi : impossible de dire
   * s'ils sont ceux de l'appareil révoqué, et les appareils légitimes les
   * réenregistrent à leur prochain démarrage.
   */
  async revokeSession(sessionId: string, reason: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const session = await tx.userSession.update({
        where: { id: sessionId },
        data: { revokedAt: new Date(), revokedReason: reason },
      });
      await tx.refreshToken.updateMany({
        where: { sessionId, status: RefreshTokenStatus.ACTIVE },
        data: { status: RefreshTokenStatus.REVOKED },
      });
      await tx.deviceToken.deleteMany({
        where: { userId: session.userId, OR: [{ sessionId }, { sessionId: null }] },
      });
    });
  }

  /**
   * Révoque toutes les sessions actives d'un utilisateur (sauf exclusion),
   * et supprime les jetons push de toutes celles qui tombent — ceux de la
   * session conservée restent. Sert le changement et la réinitialisation de
   * mot de passe, la déconnexion des autres appareils et la reprise d'un
   * compte par la connexion sociale : un squatteur évincé ne reçoit plus les
   * notifications du propriétaire.
   */
  async revokeAllSessions(userId: string, reason: string, exceptSessionId?: string): Promise<void> {
    const where = {
      userId,
      revokedAt: null,
      ...(exceptSessionId === undefined ? {} : { id: { not: exceptSessionId } }),
    };
    await this.prisma.$transaction([
      this.prisma.refreshToken.updateMany({
        where: { session: where, status: RefreshTokenStatus.ACTIVE },
        data: { status: RefreshTokenStatus.REVOKED },
      }),
      this.prisma.deviceToken.deleteMany({
        where: {
          userId,
          ...(exceptSessionId === undefined
            ? {}
            : { OR: [{ sessionId: null }, { sessionId: { not: exceptSessionId } }] }),
        },
      }),
      this.prisma.userSession.updateMany({
        where,
        data: { revokedAt: new Date(), revokedReason: reason },
      }),
    ]);
  }

  /**
   * Supprime toutes les sessions d'un utilisateur — et, par cascade, leurs
   * refresh tokens. Réservé à la suppression de compte : ipAddress,
   * userAgent, deviceName et devicePlatform sont des données personnelles
   * qui ne doivent pas survivre au compte sans échéance (le journal d'audit
   * garde sa propre ipAddress pour l'enquête). `tx` : la suppression
   * s'inscrit dans la transaction du compte, jamais seule.
   */
  async deleteAllSessions(userId: string, tx: Prisma.TransactionClient): Promise<void> {
    await tx.userSession.deleteMany({ where: { userId } });
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
