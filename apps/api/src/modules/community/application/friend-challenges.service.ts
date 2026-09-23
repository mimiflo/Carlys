import {
  FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR,
  type CreateFriendChallengeRequest,
  type FriendChallenge as FriendChallengeContract,
} from '@carlys/api-contracts';
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { FriendRequestStatus } from '@prisma/client';
import { blankToNull } from '../../../common/utilities/blank-to-null';
import { CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import { CommunityRepository } from '../infrastructure/community.repository';
import {
  type FriendChallengeWithMembers,
  FriendChallengesRepository,
} from '../infrastructure/friend-challenges.repository';
import { CommunityNotifier } from './community-notifier';
import { finalRanks, presentFriendChallenge } from './friend-challenge.presenter';

/**
 * Plafond de défis servis en une lecture. L'écran en montre quelques-uns ;
 * la borne existe pour que la requête ne grandisse pas avec l'usage.
 */
const MAX_LISTED = 50;

/**
 * DÉFIS ENTRE AMIS : individuels, invités un par un, et clos tout seuls.
 *
 * Trois règles les séparent des défis collectifs, et ce sont elles qui ont
 * justifié des tables à part :
 *  - on n'invite QUE des amis acceptés, jamais bloqués — sinon l'invitation
 *    devient un canal de message vers quelqu'un qui ne l'a pas demandé, ce
 *    que le refus opposable des demandes d'ami avait fermé ;
 *  - le classement est INDIVIDUEL, donc partir en retire (là où quitter un
 *    défi collectif laisse sa contribution acquise au groupe) ;
 *  - la clôture ÉCRIT. Un défi collectif cesse simplement d'être lu ; ici le
 *    classement final doit rester stable même si plus personne ne regarde.
 */
@Injectable()
export class FriendChallengesService {
  constructor(
    private readonly challenges: FriendChallengesRepository,
    private readonly community: CommunityRepository,
    private readonly moderation: CommunityModerationRepository,
    private readonly notifier: CommunityNotifier,
  ) {}

  async create(
    userId: string,
    input: CreateFriendChallengeRequest,
  ): Promise<FriendChallengeContract> {
    const invites = [...new Set(input.invitedUserIds)].filter((id) => id !== userId);
    if (invites.length === 0) {
      throw new ForbiddenException(
        'Invite au moins un ami : un défi contre personne n’en est pas un.',
      );
    }
    await this.assertInvitable(userId, invites);

    const now = new Date();
    const ouverts = await this.challenges.countOpenCreatedBy(userId, now);
    if (ouverts >= FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR) {
      throw new ForbiddenException(
        `Tu as déjà ${FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR} défis en cours. Termines-en un avant d’en lancer un autre.`,
      );
    }

    const cree = await this.challenges.create(
      {
        id: input.id,
        creatorId: userId,
        title: input.title,
        // Écrit UNE fois : un rejeu de la création retombe sur le défi
        // existant sans rien réécrire, message compris.
        message: blankToNull(input.message),
        metric: input.metric,
        target: input.target ?? null,
        durationDays: input.durationDays,
        startsAt: now,
        // CALCULÉE ici, jamais reçue : une fin fournie par l'appelant est un
        // défi éternel en une requête.
        endsAt: new Date(now.getTime() + input.durationDays * 24 * 3_600_000),
      },
      invites,
    );
    // Rejeu : le défi existe déjà, on le rend tel quel sans réinviter
    // personne — une notification par tentative serait du harcèlement par
    // mauvais réseau. La notification ne porte que le TITRE, jamais le
    // message : un texte libre sur l'écran verrouillé échapperait au refus de
    // l'invitation, et il n'est lisible que des membres, dans le défi.
    if (cree) {
      await Promise.all(
        invites.map((invited) => this.notifier.challengeInvite(invited, userId, input.title)),
      );
    }
    return this.detail(userId, input.id);
  }

  /**
   * Mes défis : ceux qu'on m'a proposés et ceux que j'ai acceptés.
   *
   * Les blocages sont lus à CHAQUE lecture, comme pour le fil : le mot d'un
   * créateur qu'un blocage sépare de moi n'est plus servi (voir le
   * présentateur). La liste ET le détail, sans quoi l'un rouvrirait ce que
   * l'autre tait.
   */
  async list(userId: string): Promise<FriendChallengeContract[]> {
    const [challenges, hidden] = await Promise.all([
      this.challenges.listMine(userId, MAX_LISTED),
      this.moderation.blockedUserIdsEitherWay(userId),
    ]);
    const regles = await Promise.all(challenges.map((challenge) => this.settleIfDue(challenge)));
    return regles.map((challenge) => presentFriendChallenge(challenge, userId, hidden));
  }

  async detail(userId: string, challengeId: string): Promise<FriendChallengeContract> {
    const [mine, hidden] = await Promise.all([
      this.mine(userId, challengeId),
      this.moderation.blockedUserIdsEitherWay(userId),
    ]);
    const challenge = await this.settleIfDue(mine);
    return presentFriendChallenge(challenge, userId, hidden);
  }

  /** Accepter : on entre au classement, à zéro. */
  async accept(userId: string, challengeId: string): Promise<FriendChallengeContract> {
    const challenge = await this.mine(userId, challengeId);
    if (challenge.endsAt < new Date()) {
      throw new NotFoundException('Ce défi est terminé.');
    }
    await this.challenges.setMemberStatus(challengeId, userId, 'ACCEPTED', {
      joinedAt: new Date(),
      leftAt: null,
    });
    return this.detail(userId, challengeId);
  }

  /** Refuser, ou partir : dans les deux cas on sort du classement. */
  async decline(userId: string, challengeId: string): Promise<void> {
    const challenge = await this.mine(userId, challengeId);
    const moi = challenge.members.find((member) => member.userId === userId);
    // Refuser une invitation et quitter un défi commencé ne portent pas le
    // même nom dans l'historique, même si le geste est le même : l'écran
    // n'offre qu'un bouton, l'état dit lequel.
    await this.challenges.setMemberStatus(
      challengeId,
      userId,
      moi?.status === 'ACCEPTED' ? 'LEFT' : 'DECLINED',
      { leftAt: new Date() },
    );
  }

  /**
   * Le défi, s'il existe ET que l'appelant en est membre.
   *
   * 404 dans les deux cas : un 403 sur un défi d'inconnus confirmerait qu'il
   * existe, et de quoi il parle.
   */
  private async mine(userId: string, challengeId: string): Promise<FriendChallengeWithMembers> {
    const challenge = await this.challenges.findById(challengeId);
    if (challenge === null || !challenge.members.some((member) => member.userId === userId)) {
      throw new NotFoundException('Défi introuvable.');
    }
    return challenge;
  }

  /**
   * Règle le défi s'il est échu — MATÉRIALISATION PARESSEUSE, comme le jeu
   * du mois : aucune tâche planifiée à surveiller, la première lecture qui
   * passe après la fin fait le travail.
   *
   * La différence avec les défis collectifs, qui ne closent rien : ici le
   * classement est un RÉSULTAT, et un résultat doit exister même si plus
   * personne ne lit. L'écriture est conditionnée à `closedAt: null` côté
   * dépôt, donc deux lectures simultanées n'en règlent qu'une.
   */
  private async settleIfDue(
    challenge: FriendChallengeWithMembers,
  ): Promise<FriendChallengeWithMembers> {
    if (challenge.closedAt !== null || challenge.endsAt >= new Date()) {
      return challenge;
    }
    await this.challenges.settle(challenge.id, finalRanks(challenge));
    return (await this.challenges.findById(challenge.id)) ?? challenge;
  }

  /**
   * On n'invite QUE des amis acceptés, et jamais quelqu'un qu'un blocage
   * sépare — dans un sens comme dans l'autre.
   *
   * Un seul message pour les deux refus : rien ne doit distinguer « pas ami »
   * de « t'a bloqué », sans quoi l'invitation devient un détecteur de
   * blocage.
   */
  private async assertInvitable(userId: string, invitedUserIds: string[]): Promise<void> {
    for (const invited of invitedUserIds) {
      const friendship = await this.community.findFriendshipBetween(userId, invited);
      if (
        friendship === null ||
        friendship.status !== FriendRequestStatus.ACCEPTED ||
        (await this.moderation.isBlockedEitherWay(userId, invited))
      ) {
        throw new ForbiddenException('Tu ne peux défier que tes amis.');
      }
    }
  }
}
