import {
  type NotificationCategory as NotificationCategoryContract,
  type NotificationPreferencesResponse,
} from '@carlys/api-contracts';
import { Inject, Injectable } from '@nestjs/common';
import { type DevicePlatform, NotificationCategory } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import {
  PUSH_SENDER_PORT,
  type PushMessage,
  type PushSenderPort,
} from '../domain/push-sender.port';
import { DeviceTokensRepository } from '../infrastructure/device-tokens.repository';
import { NotificationPreferencesRepository } from '../infrastructure/notification-preferences.repository';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly tokens: DeviceTokensRepository,
    private readonly preferences: NotificationPreferencesRepository,
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
   * Toutes les catégories, y compris celles jamais réglées : elles valent
   * « accepté ». Un écran qui devrait deviner les manquantes finirait par
   * diverger du serveur.
   */
  async preferencesOf(userId: string): Promise<NotificationPreferencesResponse> {
    const disabled = await this.preferences.disabledCategories(userId);
    return {
      preferences: Object.values(NotificationCategory).map((category) => ({
        category,
        enabled: !disabled.has(category),
      })),
    };
  }

  setPreference(
    userId: string,
    category: NotificationCategoryContract,
    enabled: boolean,
  ): Promise<void> {
    return this.preferences.set(userId, category, enabled);
  }

  /**
   * Envoie à TOUS les appareils de la personne. Ne lève JAMAIS : une
   * notification perdue ne casse aucun flux métier — l'échec est journalisé
   * et les jetons que FCM déclare morts sont purgés au passage.
   *
   * Le refus est respecté ICI, à l'envoi. Une préférence que seul le
   * téléphone connaîtrait laisserait la notification arriver quand même, et
   * ne servirait donc à rien.
   */
  async sendToUser(
    userId: string,
    message: PushMessage,
    category: NotificationCategoryContract,
  ): Promise<void> {
    if (!this.sender.enabled) {
      return;
    }
    try {
      if (!(await this.preferences.isEnabled(userId, category))) {
        return;
      }
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
