import { type CreateFriendChallengeRequest } from '@carlys/api-contracts';
import { NotFoundException } from '@nestjs/common';
import { type CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import { type CommunityRepository } from '../infrastructure/community.repository';
import {
  type FriendChallengeWithMembers,
  type FriendChallengesRepository,
} from '../infrastructure/friend-challenges.repository';
import { type CommunityNotifier } from './community-notifier';
import { FriendChallengesService } from './friend-challenges.service';

const CHLOE = 'utilisateur-chloe';
const BORIS = 'utilisateur-boris';
const NOW = new Date('2026-09-23T08:15:00.000Z');

/** Le statut de Boris dans le défi de Chloé. */
type MemberStatus = FriendChallengeWithMembers['members'][number]['status'];

/** Le défi tel que le dépôt le relit après la création ; Boris y est invité. */
function stored(
  message: string | null,
  borisStatus: MemberStatus = 'INVITED',
): FriendChallengeWithMembers {
  return {
    id: 'defi-1',
    creatorId: CHLOE,
    title: 'Qui court le plus',
    message,
    metric: 'DISTANCE_METERS',
    target: null,
    durationDays: 7,
    startsAt: NOW,
    // Relative à l'horloge réelle : le défi doit rester OUVERT quel que soit
    // le jour où la suite tourne, sans quoi la lecture tenterait de le régler.
    endsAt: new Date(Date.now() + 7 * 24 * 3_600_000),
    status: 'OPEN',
    closedAt: null,
    createdAt: NOW,
    updatedAt: NOW,
    creator: { profile: { displayName: 'Chloé' } },
    members: [CHLOE, BORIS].map((userId) => ({
      challengeId: 'defi-1',
      userId,
      status: userId === CHLOE ? ('ACCEPTED' as const) : borisStatus,
      invitedById: CHLOE,
      contribution: 0,
      joinedAt: userId === CHLOE ? NOW : null,
      leftAt: null,
      finalRank: null,
      user: { profile: { displayName: userId === CHLOE ? 'Chloé' : 'Boris' } },
    })),
  };
}

/**
 * `blockedEitherWay` : ce que le dépôt de modération répond pour celui qui
 * lit — les personnes qu'un blocage sépare de lui, dans un sens ou l'autre.
 */
function build(
  created: boolean,
  message: string | null,
  blockedEitherWay: string[] = [],
  borisStatus: MemberStatus = 'INVITED',
) {
  const challenges = {
    create: jest.fn().mockResolvedValue(created),
    countOpenCreatedBy: jest.fn().mockResolvedValue(0),
    findById: jest.fn().mockResolvedValue(stored(message, borisStatus)),
    listMine: jest.fn().mockResolvedValue([stored(message, borisStatus)]),
    setMemberStatus: jest.fn().mockResolvedValue(undefined),
  };
  const community = {
    findFriendshipBetween: jest.fn().mockResolvedValue({ status: 'ACCEPTED' }),
  };
  const moderation = {
    isBlockedEitherWay: jest.fn().mockResolvedValue(false),
    blockedUserIdsEitherWay: jest.fn().mockResolvedValue(new Set(blockedEitherWay)),
  };
  const notifier = { challengeInvite: jest.fn().mockResolvedValue(undefined) };
  const service = new FriendChallengesService(
    challenges as unknown as FriendChallengesRepository,
    community as unknown as CommunityRepository,
    moderation as unknown as CommunityModerationRepository,
    notifier as unknown as CommunityNotifier,
  );
  return { service, challenges, moderation, notifier };
}

const request = (message?: string | null): CreateFriendChallengeRequest => ({
  id: 'defi-1',
  title: 'Qui court le plus',
  metric: 'DISTANCE_METERS',
  target: null,
  durationDays: 7,
  invitedUserIds: [BORIS],
  ...(message === undefined ? {} : { message }),
});

describe('FriendChallengesService.create — le mot du créateur', () => {
  it('écrit le message découpé des blancs autour', async () => {
    const { service, challenges } = build(true, 'On y va ?');

    await service.create(CHLOE, request('  On y va ?  '));

    expect(challenges.create).toHaveBeenCalledWith(
      expect.objectContaining({ message: 'On y va ?' }),
      [BORIS],
    );
  });

  it.each([
    ['absent', undefined],
    ['null', null],
    ['vide', ''],
    ['blanc', '   '],
  ])('un message %s s’écrit NULL', async (_label, message) => {
    const { service, challenges } = build(true, null);

    const presented = await service.create(CHLOE, request(message));

    expect(challenges.create).toHaveBeenCalledWith(expect.objectContaining({ message: null }), [
      BORIS,
    ]);
    expect(presented.message).toBeNull();
  });

  it('la notification d’invitation porte le titre, JAMAIS le message', async () => {
    const { service, notifier } = build(true, 'Texte privé du défi');

    await service.create(CHLOE, request('Texte privé du défi'));

    // L'identifiant du défi voyage aussi : c'est lui que le toucher ouvre.
    expect(notifier.challengeInvite).toHaveBeenCalledWith(
      BORIS,
      CHLOE,
      'defi-1',
      'Qui court le plus',
    );
    expect(JSON.stringify(notifier.challengeInvite.mock.calls)).not.toContain('Texte privé');
  });

  it('un rejeu rend le défi TEL QU’IL EST en base, sans réinviter', async () => {
    // Le dépôt refuse la seconde création (même id) : le message déjà écrit
    // reste celui qui est rendu, pas celui du rejeu.
    const { service, notifier } = build(false, 'Le premier mot');

    const presented = await service.create(CHLOE, request('Un autre mot'));

    expect(presented.message).toBe('Le premier mot');
    expect(notifier.challengeInvite).not.toHaveBeenCalled();
  });

  it('la réponse porte l’heure de création, la durée et le créateur marqué', async () => {
    const { service } = build(true, 'On y va ?');

    const presented = await service.create(CHLOE, request('On y va ?'));

    expect(presented).toMatchObject({
      createdAt: NOW.toISOString(),
      durationDays: 7,
      myStatus: 'ACCEPTED',
    });
    expect(presented.members.find((entry) => entry.isMe)?.isCreator).toBe(true);
  });
});

describe('FriendChallengesService — lecture après un blocage', () => {
  it('un défi ACCEPTÉ reste lisible, mot du créateur bloqué tu, dans un sens ou l’autre', async () => {
    const { service, moderation } = build(true, 'Un mot blessant', [CHLOE], 'ACCEPTED');

    const liste = await service.list(BORIS);
    const detail = await service.detail(BORIS, 'defi-1');

    // Lus pour CELUI QUI REGARDE : c'est l'ensemble « dans les deux sens ».
    expect(moderation.blockedUserIdsEitherWay).toHaveBeenCalledWith(BORIS);
    expect(liste.map((entry) => entry.message)).toEqual([null]);
    expect(detail.message).toBeNull();
    // Le défi reste là, avec son créateur : seul le texte libre se tait.
    expect(detail.creatorDisplayName).toBe('Chloé');
  });

  it('accepter sans blocage rend la même forme, mot compris', async () => {
    const { service, challenges } = build(true, 'On y va ?');

    const accepte = await service.accept(BORIS, 'defi-1');

    expect(challenges.setMemberStatus).toHaveBeenCalledWith('defi-1', BORIS, 'ACCEPTED', {
      joinedAt: expect.any(Date) as Date,
      leftAt: null,
    });
    expect(accepte.message).toBe('On y va ?');
  });

  it('sans blocage, le mot est servi', async () => {
    const { service } = build(true, 'On y va ?');

    expect((await service.detail(BORIS, 'defi-1')).message).toBe('On y va ?');
  });
});

describe('FriendChallengesService — une INVITATION d’un créateur bloqué disparaît', () => {
  // Boris est invité (pas encore accepté) par Chloé, qu'un blocage sépare de
  // lui, dans un sens ou l'autre : l'ensemble lu est le même.
  const invitationMasquee = () => build(true, 'Un mot blessant', [CHLOE], 'INVITED');

  it('absente de la liste', async () => {
    const { service } = invitationMasquee();

    expect(await service.list(BORIS)).toEqual([]);
  });

  it('introuvable au détail, avec le 404 d’un défi inconnu', async () => {
    const { service } = invitationMasquee();

    await expect(service.detail(BORIS, 'defi-1')).rejects.toThrow(
      new NotFoundException('Défi introuvable.'),
    );
  });

  it('introuvable à l’acceptation : rien n’est écrit, même message', async () => {
    const { service, challenges } = invitationMasquee();

    await expect(service.accept(BORIS, 'defi-1')).rejects.toThrow(
      new NotFoundException('Défi introuvable.'),
    );
    expect(challenges.setMemberStatus).not.toHaveBeenCalled();
  });

  it('introuvable au refus aussi : elle a disparu partout', async () => {
    const { service, challenges } = invitationMasquee();

    await expect(service.decline(BORIS, 'defi-1')).rejects.toThrow(NotFoundException);
    expect(challenges.setMemberStatus).not.toHaveBeenCalled();
  });

  it('le créateur, lui, voit toujours son défi et son invité', async () => {
    // La règle porte sur l'INVITATION reçue, pas sur le défi : Chloé est
    // membre acceptée d'office, et le blocage ne réécrit pas sa liste.
    const { service } = build(true, 'Un mot blessant', [BORIS], 'INVITED');

    const siens = await service.list(CHLOE);

    expect(siens).toHaveLength(1);
    expect(siens[0]?.members.map((member) => member.userId)).toEqual([CHLOE, BORIS]);
  });

  it('sans blocage, l’invitation reste lisible et acceptable', async () => {
    const { service } = build(true, 'On y va ?', [], 'INVITED');

    expect(await service.list(BORIS)).toHaveLength(1);
    expect((await service.detail(BORIS, 'defi-1')).myStatus).toBe('INVITED');
  });
});

describe.each(['DECLINED', 'LEFT'] as const)(
  'FriendChallengesService — hors du classement (%s), un créateur bloqué fait disparaître le défi',
  (statut) => {
    // Boris a refusé l'invitation de Chloé, ou quitté son défi, puis un
    // blocage les a séparés. Il n'est pas au classement : rien de partagé
    // ne l'y retient. Réaccepter rouvrait sinon ce que le blocage a fermé.
    const horsClassement = () => build(true, 'Un mot blessant', [CHLOE], statut);

    it('introuvable au détail, avec le 404 d’un défi inconnu', async () => {
      const { service } = horsClassement();

      await expect(service.detail(BORIS, 'defi-1')).rejects.toThrow(
        new NotFoundException('Défi introuvable.'),
      );
    });

    it('introuvable à l’acceptation : rien n’est écrit, même message', async () => {
      const { service, challenges } = horsClassement();

      await expect(service.accept(BORIS, 'defi-1')).rejects.toThrow(
        new NotFoundException('Défi introuvable.'),
      );
      expect(challenges.setMemberStatus).not.toHaveBeenCalled();
    });

    it('introuvable au refus aussi', async () => {
      const { service, challenges } = horsClassement();

      await expect(service.decline(BORIS, 'defi-1')).rejects.toThrow(
        new NotFoundException('Défi introuvable.'),
      );
      expect(challenges.setMemberStatus).not.toHaveBeenCalled();
    });

    it('sans blocage, il se lit et se réaccepte', async () => {
      const { service, challenges } = build(true, 'On y va ?', [], statut);

      expect((await service.detail(BORIS, 'defi-1')).myStatus).toBe(statut);
      await service.accept(BORIS, 'defi-1');
      expect(challenges.setMemberStatus).toHaveBeenCalledWith('defi-1', BORIS, 'ACCEPTED', {
        joinedAt: expect.any(Date) as Date,
        leftAt: null,
      });
    });
  },
);
