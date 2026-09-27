import { Injectable } from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { CommunityRepository } from '../infrastructure/community.repository';
import { FriendChallengesRepository } from '../infrastructure/friend-challenges.repository';
import { LeaguesRepository } from '../infrastructure/leagues.repository';
import { finalRanks } from './friend-challenge.presenter';

/**
 * UN COMPTE SUPPRIMÉ QUITTE LA COMMUNAUTÉ TOUT DE SUITE, dans la
 * transaction de la suppression — pas trente jours plus tard, à la purge.
 * Jusque-là, les autres continuaient de voir un nom vide au classement, dans
 * leurs défis et dans leur fil.
 *
 *  - LIGUE : la personne en sort, comme on la quitte (`joinsLeague: false`).
 *    Sa ligne de la semaine RESTE et compte au règlement et aux rangs,
 *    calculés sur le groupe entier : personne ne remonte d'un cran, rien
 *    n'est faussé. Seule la lecture la tait.
 *  - DÉFIS ENTRE AMIS : voir `FriendChallengesRepository.withdrawAccount`.
 *  - ENCOURAGEMENTS : ceux qu'elle a envoyés quittent le fil des autres.
 *
 * Les amitiés n'ont rien à faire ici : les listes lisent déjà les seuls
 * comptes actifs.
 */
@Injectable()
export class CommunityWithdrawalService {
  constructor(
    private readonly leagues: LeaguesRepository,
    private readonly friendChallenges: FriendChallengesRepository,
    private readonly community: CommunityRepository,
  ) {}

  async withdraw(userId: string, tx: Prisma.TransactionClient): Promise<void> {
    const now = new Date();
    await this.leagues.setJoined(userId, false, tx);
    // Un défi échu que personne n'a encore ouvert se règle AVANT qu'elle en
    // sorte, avec elle : un résultat ne dépend pas du jour de la suppression.
    for (const challenge of await this.friendChallenges.dueUnsettledOf(userId, now, tx)) {
      await this.friendChallenges.settle(challenge.id, finalRanks(challenge), tx);
    }
    await this.friendChallenges.withdrawAccount(userId, now, tx);
    await this.community.deleteEncouragementsSentBy(userId, tx);
  }
}
