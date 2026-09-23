import { type FriendChallengeWithMembers } from '../infrastructure/friend-challenges.repository';
import { presentFriendChallenge } from './friend-challenge.presenter';

const CHLOE = 'utilisateur-chloe';
const BORIS = 'utilisateur-boris';
const CREATED_AT = new Date('2026-09-23T08:15:00.000Z');
/** Aucun blocage entre celui qui regarde et les autres membres. */
const AUCUN: ReadonlySet<string> = new Set();

function member(
  userId: string,
  displayName: string,
  overrides: Partial<FriendChallengeWithMembers['members'][number]> = {},
): FriendChallengeWithMembers['members'][number] {
  return {
    challengeId: 'defi-1',
    userId,
    status: 'ACCEPTED',
    invitedById: CHLOE,
    contribution: 0,
    joinedAt: CREATED_AT,
    leftAt: null,
    finalRank: null,
    user: { profile: { displayName } },
    ...overrides,
  };
}

function challenge(
  overrides: Partial<FriendChallengeWithMembers> = {},
): FriendChallengeWithMembers {
  return {
    id: 'defi-1',
    creatorId: CHLOE,
    title: 'Qui court le plus',
    message: 'On verra qui tient la semaine.',
    metric: 'DISTANCE_METERS',
    target: null,
    durationDays: 7,
    startsAt: CREATED_AT,
    endsAt: new Date('2026-09-30T08:15:00.000Z'),
    status: 'OPEN',
    closedAt: null,
    createdAt: CREATED_AT,
    updatedAt: CREATED_AT,
    creator: { profile: { displayName: 'Chloé' } },
    members: [
      member(BORIS, 'Boris', { status: 'INVITED', joinedAt: null }),
      member(CHLOE, 'Chloé', { contribution: 1_200 }),
    ],
    ...overrides,
  };
}

describe('presentFriendChallenge — le message et son heure', () => {
  it('rend le message, sa durée et l’heure de création du défi (ISO UTC)', () => {
    const presented = presentFriendChallenge(challenge(), BORIS, AUCUN);

    expect(presented).toMatchObject({
      message: 'On verra qui tient la semaine.',
      durationDays: 7,
      createdAt: '2026-09-23T08:15:00.000Z',
      creatorDisplayName: 'Chloé',
      myStatus: 'INVITED',
    });
  });

  it('un défi sans mot rend `null`, jamais une chaîne vide', () => {
    expect(presentFriendChallenge(challenge({ message: null }), BORIS, AUCUN).message).toBeNull();
  });

  it('marque le créateur parmi les membres, indépendamment de qui regarde', () => {
    for (const viewer of [BORIS, CHLOE]) {
      const members = presentFriendChallenge(challenge(), viewer, AUCUN).members;
      expect(members.find((entry) => entry.userId === CHLOE)?.isCreator).toBe(true);
      expect(members.find((entry) => entry.userId === BORIS)?.isCreator).toBe(false);
    }
  });

  it('le créateur, accepté d’office, est classé ; l’invité ne l’est pas encore', () => {
    const members = presentFriendChallenge(challenge(), BORIS, AUCUN).members;

    expect(members.find((entry) => entry.isCreator)).toMatchObject({
      status: 'ACCEPTED',
      rank: 1,
      isMe: false,
    });
    expect(members.find((entry) => entry.isMe)).toMatchObject({ status: 'INVITED', rank: null });
  });
});

describe('presentFriendChallenge — un blocage tait le mot du créateur', () => {
  it('le mot d’un créateur séparé par un blocage n’est plus servi', () => {
    // Boris a bloqué Chloé, ou l'inverse : l'ensemble est lu dans les deux
    // sens par le service, le présentateur n'a qu'à s'y fier.
    const presented = presentFriendChallenge(challenge(), BORIS, new Set([CHLOE]));

    expect(presented.message).toBeNull();
  });

  it('le défi reste lisible : titre, créateur et classement ne se réécrivent pas', () => {
    const presented = presentFriendChallenge(challenge(), BORIS, new Set([CHLOE]));

    expect(presented).toMatchObject({ title: 'Qui court le plus', creatorDisplayName: 'Chloé' });
    expect(presented.members.find((entry) => entry.isCreator)).toMatchObject({
      userId: CHLOE,
      rank: 1,
    });
  });

  it('seul le blocage du CRÉATEUR compte : un autre membre bloqué ne tait rien', () => {
    const presented = presentFriendChallenge(challenge(), BORIS, new Set(['utilisateur-dora']));

    expect(presented.message).toBe('On verra qui tient la semaine.');
  });
});
