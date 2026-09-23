import { type CreateFriendChallengeRequest } from '@carlys/api-contracts';
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

/** Le défi tel que le dépôt le relit après la création. */
function stored(message: string | null): FriendChallengeWithMembers {
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
      status: userId === CHLOE ? ('ACCEPTED' as const) : ('INVITED' as const),
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
function build(created: boolean, message: string | null, blockedEitherWay: string[] = []) {
  const challenges = {
    create: jest.fn().mockResolvedValue(created),
    countOpenCreatedBy: jest.fn().mockResolvedValue(0),
    findById: jest.fn().mockResolvedValue(stored(message)),
    listMine: jest.fn().mockResolvedValue([stored(message)]),
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

    expect(notifier.challengeInvite).toHaveBeenCalledWith(BORIS, CHLOE, 'Qui court le plus');
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
  it('la liste et le détail taisent le mot d’un créateur bloqué, dans un sens ou l’autre', async () => {
    const { service, moderation } = build(true, 'Un mot blessant', [CHLOE]);

    const liste = await service.list(BORIS);
    const detail = await service.detail(BORIS, 'defi-1');

    // Lus pour CELUI QUI REGARDE : c'est l'ensemble « dans les deux sens ».
    expect(moderation.blockedUserIdsEitherWay).toHaveBeenCalledWith(BORIS);
    expect(liste.map((entry) => entry.message)).toEqual([null]);
    expect(detail.message).toBeNull();
    // Le défi reste là, avec son créateur : seul le texte libre se tait.
    expect(detail.creatorDisplayName).toBe('Chloé');
  });

  it('accepter rend la même forme, mot masqué compris', async () => {
    const { service, challenges } = build(true, 'Un mot blessant', [CHLOE]);

    const accepte = await service.accept(BORIS, 'defi-1');

    expect(challenges.setMemberStatus).toHaveBeenCalledWith('defi-1', BORIS, 'ACCEPTED', {
      joinedAt: expect.any(Date) as Date,
      leftAt: null,
    });
    expect(accepte.message).toBeNull();
  });

  it('sans blocage, le mot est servi', async () => {
    const { service } = build(true, 'On y va ?');

    expect((await service.detail(BORIS, 'defi-1')).message).toBe('On y va ?');
  });
});
