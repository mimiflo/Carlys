import { Injectable } from '@nestjs/common';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../../config/app-config.service';
import {
  type PushMessage,
  type PushSendOutcome,
  type PushSenderPort,
} from '../domain/push-sender.port';

/** Nom d'application dédié : ne collisionne jamais avec un autre init. */
const FIREBASE_APP_NAME = 'carlys-push';

/** Codes FCM signifiant « ce jeton ne sert plus à rien » — à purger. */
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * Seul fichier du dépôt qui connaisse firebase-admin.
 *
 * Sans `FIREBASE_SERVICE_ACCOUNT_JSON`, l'envoyeur se déclare désactivé :
 * l'API démarre, les jetons s'enregistrent, aucun envoi ne part. Fournir la
 * clé réactive les envois sans aucun changement de code.
 */
@Injectable()
export class FcmPushSender implements PushSenderPort {
  /** Créé paresseusement : sans clé, le module reste chargeable. */
  private messaging: Messaging | null = null;
  /** Clé illisible : on le dit UNE fois, puis on reste désactivé. */
  private broken = false;

  constructor(
    private readonly config: AppConfigService,
    @InjectPinoLogger(FcmPushSender.name)
    private readonly logger: PinoLogger,
  ) {}

  get enabled(): boolean {
    return this.config.firebaseServiceAccountJson !== undefined && !this.broken;
  }

  async send(token: string, message: PushMessage): Promise<PushSendOutcome> {
    const messaging = this.ensureMessaging();
    if (messaging === null) {
      return 'failed';
    }
    try {
      await messaging.send({
        token,
        notification: { title: message.title, body: message.body },
      });
      return 'sent';
    } catch (error) {
      if (isInvalidTokenError(error)) {
        return 'invalid-token';
      }
      this.logger.error({ err: error }, 'Envoi FCM échoué');
      return 'failed';
    }
  }

  private ensureMessaging(): Messaging | null {
    if (this.messaging !== null) {
      return this.messaging;
    }
    const raw = this.config.firebaseServiceAccountJson;
    if (raw === undefined || this.broken) {
      return null;
    }
    try {
      const serviceAccount = JSON.parse(raw) as Parameters<typeof cert>[0];
      const app =
        getApps().find((candidate) => candidate.name === FIREBASE_APP_NAME) ??
        initializeApp({ credential: cert(serviceAccount) }, FIREBASE_APP_NAME);
      this.messaging = getMessaging(app);
      return this.messaging;
    } catch (error) {
      this.broken = true;
      this.logger.error(
        { err: error },
        'FIREBASE_SERVICE_ACCOUNT_JSON illisible — envois push désactivés',
      );
      return null;
    }
  }
}

function isInvalidTokenError(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) {
    return false;
  }
  const code = (error as { code?: unknown }).code;
  return typeof code === 'string' && INVALID_TOKEN_CODES.has(code);
}
