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
   */
  async upsert(input: { userId: string; token: string; platform: DevicePlatform }): Promise<void> {
    await this.prisma.deviceToken.upsert({
      where: { token: input.token },
      create: input,
      update: { userId: input.userId, platform: input.platform },
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

  async listTokens(userId: string): Promise<string[]> {
    const rows = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    return rows.map((row) => row.token);
  }
}
