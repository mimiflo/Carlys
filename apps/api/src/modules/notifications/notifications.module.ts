import { Module } from '@nestjs/common';
import { NotificationsService } from './application/notifications.service';
import { PUSH_SENDER_PORT } from './domain/push-sender.port';
import { DeviceTokensRepository } from './infrastructure/device-tokens.repository';
import { NotificationPreferencesRepository } from './infrastructure/notification-preferences.repository';
import { FcmPushSender } from './infrastructure/fcm.sender';
import { NotificationsController } from './presentation/http/notifications.controller';

/**
 * Notifications push — enregistrement des jetons d'appareil et envoi FCM.
 *
 * L'envoyeur n'est branché qu'ici, derrière `PUSH_SENDER_PORT` : les tests
 * substituent un faux et ne sortent jamais sur le réseau. Sans compte de
 * service Firebase configuré, l'envoi est simplement inactif — les jetons
 * s'enregistrent quand même, prêts pour l'activation.
 */
@Module({
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    DeviceTokensRepository,
    NotificationPreferencesRepository,
    { provide: PUSH_SENDER_PORT, useClass: FcmPushSender },
  ],
  // Exporté pour les domaines qui notifient (communauté).
  exports: [NotificationsService],
})
export class NotificationsModule {}
