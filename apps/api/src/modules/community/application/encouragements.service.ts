import { type Encouragement as EncouragementContract } from '@carlys/api-contracts';
import { ForbiddenException, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { FriendRequestStatus } from '@prisma/client';
import { CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import { CommunityRepository } from '../infrastructure/community.repository';
import { CommunityNotifier } from './community-notifier';

const FEED_LIMIT = 50;

/**
 * Encouragements qu'une personne peut envoyer au MÊME ami sur 24 heures
 * glissantes.
 *
 * Chaque encouragement pousse une notification sur tous les appareils du
 * destinataire. Sans plafond, un ami pouvait en envoyer en boucle — jusqu'à
 * 6 000 par heure à la même personne sous la seule limite globale (mesuré :
 * 40 envois consécutifs, 40 × 201, 40 lignes). Vingt par jour laissent toute
 * la place à un usage chaleureux, et plus aucune à l'inondation.
 */
export const ENCOURAGEMENTS_PER_FRIEND_PER_DAY = 20;

/** Le fil d'encouragements reçus, et l'envoi d'un encouragement à un ami. */
@Injectable()
export class EncouragementsService {
  constructor(
    private readonly community: CommunityRepository,
    private readonly moderation: CommunityModerationRepository,
    /** Les envois n'échouent jamais un flux métier : voir CommunityNotifier. */
    private readonly notifier: CommunityNotifier,
  ) {}

  /** Le fil tait les personnes bloquées, dans un sens comme dans l'autre. */
  async feed(userId: string): Promise<EncouragementContract[]> {
    const hidden = await this.moderation.blockedUserIdsEitherWay(userId);
    const rows = await this.community.listEncouragements(userId, FEED_LIMIT, [...hidden]);
    return rows.map((row) => ({
      id: row.id,
      fromUserId: row.senderId,
      fromDisplayName: row.sender.profile?.displayName ?? 'Membre Carlys',
      message: row.message,
      sentAt: row.createdAt.toISOString(),
    }));
  }

  async encourage(userId: string, recipientUserId: string, message: string): Promise<void> {
    const friendship = await this.community.findFriendshipBetween(userId, recipientUserId);
    if (
      friendship === null ||
      friendship.status !== FriendRequestStatus.ACCEPTED ||
      (await this.moderation.isBlockedEitherWay(userId, recipientUserId))
    ) {
      // On n'écrit pas chez quelqu'un qui n'est pas un ami. 403, pas 404 :
      // l'appelant connaît déjà cet identifiant (il vient de sa liste d'amis).
      // Un blocage répond pareil : rien ne distingue « bloqué » de « plus ami ».
      throw new ForbiddenException('Tu ne peux encourager que tes amis.');
    }
    const created = await this.community.createEncouragementWithinLimit(
      userId,
      recipientUserId,
      message,
      { max: ENCOURAGEMENTS_PER_FRIEND_PER_DAY, windowMs: 24 * 3_600_000 },
    );
    if (!created) {
      throw new HttpException(
        `Tu as déjà envoyé ${ENCOURAGEMENTS_PER_FRIEND_PER_DAY} encouragements à cet ami aujourd’hui. Garde les suivants pour demain !`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    this.notifier.encouragement(recipientUserId, userId, message);
  }
}
