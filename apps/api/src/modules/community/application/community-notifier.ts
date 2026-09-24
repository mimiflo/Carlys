import { type NotificationCategory, type PushData } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { NotificationsService } from '../../notifications/application/notifications.service';
import { type PushMessage } from '../../notifications/domain/push-sender.port';
import { CommunityRepository } from '../infrastructure/community.repository';

/** Demandes d'ami et encouragements mènent à l'onglet Amis. */
const VERS_LES_AMIS: PushData = { destination: 'community-friends' };

/**
 * Notifications poussées de la communauté, au nom d'une personne.
 *
 * Aucun envoi n'échoue JAMAIS un flux métier : l'échec est journalisé et
 * l'appel métier aboutit quand même. Le nom affiché est lu au moment de
 * l'envoi (jamais l'e-mail), et la CATÉGORIE voyage jusqu'à l'envoi : c'est
 * elle qui permet de couper les demandes d'ami sans couper les
 * encouragements.
 *
 * Chaque message porte sa DESTINATION (`data`, contrat `PushData`) : sans
 * elle, le toucher ouvrait l'application, jamais l'écran concerné.
 */
@Injectable()
export class CommunityNotifier {
  constructor(
    private readonly community: CommunityRepository,
    private readonly notifications: NotificationsService,
    @InjectPinoLogger(CommunityNotifier.name)
    private readonly logger: PinoLogger,
  ) {}

  newRequest(requesterId: string, addresseeId: string): Promise<void> {
    return this.notify(addresseeId, requesterId, 'FRIEND_REQUESTS', (fromName) => ({
      title: 'Nouvelle demande d’ami',
      body: `${fromName} souhaite devenir ton ami.`,
      data: VERS_LES_AMIS,
    }));
  }

  requestAccepted(accepterId: string, requesterId: string): Promise<void> {
    return this.notify(requesterId, accepterId, 'FRIEND_REQUESTS', (fromName) => ({
      title: 'Demande acceptée',
      body: `${fromName} a accepté ta demande d’ami.`,
      data: VERS_LES_AMIS,
    }));
  }

  encouragement(recipientId: string, senderId: string, message: string): Promise<void> {
    return this.notify(recipientId, senderId, 'ENCOURAGEMENTS', (fromName) => ({
      title: `Encouragement de ${fromName}`,
      body: message,
      data: VERS_LES_AMIS,
    }));
  }

  /**
   * Invitation à un défi. Catégorie DISTINCTE des encouragements : quelqu'un
   * peut vouloir des encouragements sans vouloir être défié, et le refus
   * d'une famille ne doit pas couper l'autre.
   *
   * Le toucher ouvre CE défi, d'où son identifiant ; jamais son mot, qui ne
   * se lit que dans le défi (voir `FriendChallengesService.create`).
   */
  challengeInvite(
    invitedId: string,
    fromUserId: string,
    challengeId: string,
    title: string,
  ): Promise<void> {
    const data: PushData = { destination: 'friend-challenge', challengeId };
    return this.notify(invitedId, fromUserId, 'CHALLENGE_INVITES', (fromName) => ({
      title: 'Nouveau défi',
      body: `${fromName} te défie : ${title}`,
      data,
    }));
  }

  private async notify(
    recipientId: string,
    fromUserId: string,
    category: NotificationCategory,
    compose: (fromName: string) => PushMessage,
  ): Promise<void> {
    if (!this.notifications.pushEnabled) {
      return;
    }
    try {
      const fromName = await this.community.displayNameOf(fromUserId);
      await this.notifications.sendToUser(recipientId, compose(fromName), category);
    } catch (error) {
      this.logger.error({ err: error, recipientId }, 'Notification communauté non envoyée');
    }
  }
}
