import { Inject, Injectable } from '@nestjs/common';
import { type DevicePlatform } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import {
  PUSH_SENDER_PORT,
  type PushMessage,
  type PushSenderPort,
} from '../domain/push-sender.port';
import { DeviceTokensRepository } from '../infrastructure/device-tokens.repository';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly tokens: DeviceTokensRepository,
    @Inject(PUSH_SENDER_PORT) private readonly sender: PushSenderPort,
    @InjectPinoLogger(NotificationsService.name)
    private readonly logger: PinoLogger,
  ) {}

  /** Permet aux appelants d'éviter de PRÉPARER un message qui ne partira pas. */
  get pushEnabled(): boolean {
    return this.sender.enabled;
  }

  /** Idempotent — et un appareil qui change de compte change de main. */
  async registerDevice(
    userId: string,
    input: { token: string; platform: DevicePlatform },
  ): Promise<void> {
    await this.tokens.upsert({ userId, ...input });
  }

  /** Oubli à la déconnexion. Idempotent, limité aux jetons de l'appelant. */
  async forgetDevice(userId: string, token: string): Promise<void> {
    await this.tokens.deleteForUser(userId, token);
  }

  /**
   * Envoie à TOUS les appareils de la personne. Ne lève JAMAIS : une
   * notification perdue ne casse aucun flux métier — l'échec est journalisé
   * et les jetons que FCM déclare morts sont purgés au passage.
   */
  async sendToUser(userId: string, message: PushMessage): Promise<void> {
    if (!this.sender.enabled) {
      return;
    }
    try {
      const tokens = await this.tokens.listTokens(userId);
      for (const token of tokens) {
        const outcome = await this.sender.send(token, message);
        if (outcome === 'invalid-token') {
          await this.tokens.deleteByToken(token);
        }
      }
    } catch (error) {
      this.logger.error({ err: error, userId }, 'Notification push non envoyée');
    }
  }
}
