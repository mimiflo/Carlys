import {
  FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR,
  type CreateFriendChallengeRequest,
  type FriendChallenge as FriendChallengeContract,
} from '@carlys/api-contracts';
import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FriendRequestStatus } from '@prisma/client';
import { blankToNull } from '../../../common/utilities/blank-to-null';
import { CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import { CommunityRepository } from '../infrastructure/community.repository';
import {
  type FriendChallengeWithMembers,
  FriendChallengesRepository,
} from '../infrastructure/friend-challenges.repository';
import { CommunityNotifier } from './community-notifier';
import { finalRanks, isHiddenByBlock, presentFriendChallenge } from './friend-challenge.presenter';

/**
 * Plafonds de défis servis en une lecture : les EN COURS d'abord, puis les
 * plus récents des TERMINÉS. L'écran en montre quelques-uns ; les bornes
 * existent pour que la requête ne grandisse pas avec l'usage, et elles sont
 * DEUX pour que l'historique, qui s'accumule, ne pousse jamais hors de la
 * liste un défi en cours ou une invitation en attente.
 */
const MAX_LISTED = { ongoing: 50, finished: 10 } as const;

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
    // Le REJEU est reconnu EN TÊTE, avant toute garde. La route est
    // idempotente : un client qui rejoue une création RÉUSSIE doit retrouver
    // son défi, même si le plafond est atteint depuis (c'est ce défi-là qui
    // l'a rempli) ou si un invité a quitté ses amis entre-temps. Les gardes
    // passaient avant : ce rejeu rendait 403.
    const existant = await this.challenges.findById(input.id);
    if (existant !== null) {
      if (existant.creatorId !== userId) {
        throw new ConflictException('Cet identifiant de défi est déjà utilisé.');
      }
      return this.detail(userId, input.id);
    }

    const invites = [...new Set(input.invitedUserIds)].filter((id) => id !== userId);
    if (invites.length === 0) {
      throw new ForbiddenException(
        'Invite au moins un ami : un défi contre personne n’en est pas un.',
      );
    }
    await this.assertInvitable(userId, invites);

    const now = new Date();
    const issue = await this.challenges.createWithinLimit(
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
      FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR,
    );
    if (issue === 'LIMIT') {
      throw new ForbiddenException(
        `Tu as déjà ${FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR} défis en cours. Termines-en un avant d’en lancer un autre.`,
      );
    }
    // Rejeu concurrent (`REPLAY`) : le défi existe déjà, on le rend tel quel
    // sans réinviter personne — une notification par tentative serait du
    // harcèlement par mauvais réseau. La notification ne porte que le TITRE,
    // jamais le message : un texte libre sur l'écran verrouillé échapperait
    // au refus de l'invitation, et il n'est lisible que des membres, dans le
    // défi.
    if (issue === 'CREATED') {
      await Promise.all(
        invites.map((invited) =>
          this.notifier.challengeInvite(invited, userId, input.id, input.title),
        ),
      );
    }
    return this.detail(userId, input.id);
  }

  /**
   * Mes défis : ceux qu'on m'a proposés et ceux que j'ai acceptés.
   *
   * Les blocages sont lus à CHAQUE lecture, comme pour le fil. Un défi dont
   * le créateur est séparé de moi par un blocage disparaît tant que je ne
   * suis pas à son classement (invitation en attente ou refusée, défi
   * quitté) ; un défi où je suis au classement reste, mot du créateur masqué
   * (voir le présentateur). La liste, le détail, l'acceptation ET le refus,
   * sans quoi l'un rouvrirait ce que l'autre tait.
   */
  async list(userId: string): Promise<FriendChallengeContract[]> {
    const [challenges, hidden] = await Promise.all([
      this.challenges.listMine(userId, new Date(), MAX_LISTED),
      this.moderation.blockedUserIdsEitherWay(userId),
    ]);
    const visibles = challenges.filter((challenge) => !isHiddenByBlock(challenge, userId, hidden));
    const regles = await Promise.all(visibles.map((challenge) => this.settleIfDue(challenge)));
    return regles.map((challenge) => presentFriendChallenge(challenge, userId, hidden));
  }

  async detail(userId: string, challengeId: string): Promise<FriendChallengeContract> {
    const hidden = await this.moderation.blockedUserIdsEitherWay(userId);
    const challenge = await this.settleIfDue(await this.mine(userId, challengeId, hidden));
    return presentFriendChallenge(challenge, userId, hidden);
  }

  /** Accepter : on entre au classement, à zéro. */
  async accept(userId: string, challengeId: string): Promise<FriendChallengeContract> {
    const hidden = await this.moderation.blockedUserIdsEitherWay(userId);
    // La visibilité AVANT la fin : « terminé » sur un défi masqué dirait
    // qu'il existe encore. Et elle couvre la RÉACCEPTATION : un défi refusé
    // ou quitté, puis séparé de son créateur par un blocage, est masqué lui
    // aussi — sans quoi réaccepter rouvrait ce que le blocage a fermé.
    const challenge = await this.mine(userId, challengeId, hidden);
    if (challenge.endsAt < new Date()) {
      throw new NotFoundException('Ce défi est terminé.');
    }
    await this.challenges.setMemberStatus(challengeId, userId, 'ACCEPTED', {
      joinedAt: new Date(),
      leftAt: null,
    });
    return this.detail(userId, challengeId);
  }

  /**
   * Refuser, ou partir : dans les deux cas on sort du classement.
   *
   * Un défi masqué par un blocage est introuvable ici aussi : il a disparu
   * partout, pas seulement à la lecture.
   */
  async decline(userId: string, challengeId: string): Promise<void> {
    const hidden = await this.moderation.blockedUserIdsEitherWay(userId);
    const challenge = await this.mine(userId, challengeId, hidden);
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
   * Le défi, s'il existe, que l'appelant en est membre, et qu'un blocage ne
   * le lui masque pas ([isHiddenByBlock]).
   *
   * Le MÊME 404 dans tous les cas : un 403 sur un défi d'inconnus
   * confirmerait qu'il existe, et un message propre au défi masqué dirait
   * qu'un blocage est passé par là.
   */
  private async mine(
    userId: string,
    challengeId: string,
    hidden: ReadonlySet<string>,
  ): Promise<FriendChallengeWithMembers> {
    const challenge = await this.challenges.findById(challengeId);
    if (
      challenge === null ||
      !challenge.members.some((member) => member.userId === userId) ||
      isHiddenByBlock(challenge, userId, hidden)
    ) {
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
