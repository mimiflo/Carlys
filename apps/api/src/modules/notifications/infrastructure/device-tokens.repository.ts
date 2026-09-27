import { Injectable } from '@nestjs/common';
import { type DevicePlatform } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

@Injectable()
export class DeviceTokensRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Un jeton appartient à UN utilisateur à la fois : se connecter avec un
   * autre compte sur le même appareil le réaffecte. Rejouer l'enregistrement
   * est sans effet — l'appel est idempotent.
   *
   * Il appartient aussi à la SESSION qui l'enregistre (`sessionId`) : c'est
   * ce qui le fait tomber quand cette session est révoquée (voir
   * `SessionsRepository`).
   */
  async upsert(input: {
    userId: string;
    sessionId: string;
    token: string;
    platform: DevicePlatform;
  }): Promise<void> {
    await this.prisma.deviceToken.upsert({
      where: { token: input.token },
      create: input,
      update: { userId: input.userId, sessionId: input.sessionId, platform: input.platform },
    });
  }

  /** Oubli à la déconnexion — idempotent, et jamais le jeton d'un autre. */
  async deleteForUser(userId: string, token: string): Promise<void> {
    await this.prisma.deviceToken.deleteMany({ where: { userId, token } });
  }

  /** Purge d'un jeton que FCM déclare mort, quel que soit son propriétaire. */
  async deleteByToken(token: string): Promise<void> {
    await this.prisma.deviceToken.deleteMany({ where: { token } });
  }

  /**
   * Les jetons À QUI l'on peut envoyer : ceux d'une session vivante (ni
   * révoquée, ni expirée), plus les jetons antérieurs au rattachement
   * (`sessionId` nul). La révocation supprime déjà les jetons ; ce filtre
   * couvre en plus l'expiration d'une session inactive, qui n'écrit rien.
   */
  async listTokens(userId: string, now: Date = new Date()): Promise<string[]> {
    const rows = await this.prisma.deviceToken.findMany({
      where: {
        userId,
        OR: [{ sessionId: null }, { session: { revokedAt: null, expiresAt: { gt: now } } }],
      },
      select: { token: true },
    });
    return rows.map((row) => row.token);
  }
}
