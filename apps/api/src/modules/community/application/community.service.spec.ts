import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { FriendRequestStatus } from '@prisma/client';
import { type PinoLogger } from 'nestjs-pino';
import { type NotificationsService } from '../../notifications/application/notifications.service';
import { type CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import { type CommunityRepository } from '../infrastructure/community.repository';
import { type CommunityChallengesService } from './community-challenges.service';
import { CommunityService } from './community.service';

const ME = 'utilisateur-moi';
const FRIEND = 'utilisateur-ami';

interface Stubs {
  displayNameOf: jest.Mock;
  findFriendshipBetween: jest.Mock;
  createRequest: jest.Mock;
  findRequestById: jest.Mock;
  setRequestStatus: jest.Mock;
  reopenRequest: jest.Mock;
  deleteFriendship: jest.Mock;
  listReceivedRequests: jest.Mock;
  listFriends: jest.Mock;
  findUserIdByEmail: jest.Mock;
  findUserByFriendCode: jest.Mock;
  friendCodeOf: jest.Mock;
  completedSessionStarts: jest.Mock;
  listEncouragements: jest.Mock;
  createEncouragement: jest.Mock;
  sharesProgress: jest.Mock;
  setSharesProgress: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    displayNameOf: jest.fn().mockResolvedValue('Alice'),
    findFriendshipBetween: jest.fn().mockResolvedValue(null),
    createRequest: jest.fn().mockResolvedValue({}),
    findRequestById: jest.fn().mockResolvedValue(null),
    setRequestStatus: jest.fn().mockResolvedValue({}),
    reopenRequest: jest.fn().mockResolvedValue({}),
    deleteFriendship: jest.fn().mockResolvedValue(undefined),
    listReceivedRequests: jest.fn().mockResolvedValue([]),
    listFriends: jest.fn().mockResolvedValue([]),
    findUserIdByEmail: jest.fn().mockResolvedValue(null),
    findUserByFriendCode: jest.fn().mockResolvedValue(null),
    friendCodeOf: jest.fn().mockResolvedValue('AC23DEF4'),
    completedSessionStarts: jest.fn().mockResolvedValue([]),
    listEncouragements: jest.fn().mockResolvedValue([]),
    createEncouragement: jest.fn().mockResolvedValue({}),
    sharesProgress: jest.fn().mockResolvedValue(true),
    setSharesProgress: jest.fn().mockResolvedValue(undefined),
  };
}

const loggerStub = { error: jest.fn() };
/** Les défis ont leur propre service et leur propre spec : ici, un simple relais. */
const challengesStub = { recordWorkoutCompleted: jest.fn().mockResolvedValue(undefined) };

interface NotificationsStub {
  pushEnabled: boolean;
  sendToUser: jest.Mock;
}

function buildNotifications(pushEnabled = true): NotificationsStub {
  return { pushEnabled, sendToUser: jest.fn().mockResolvedValue(undefined) };
}

interface ModerationStub {
  isBlockedEitherWay: jest.Mock;
  blockedUserIdsEitherWay: jest.Mock;
}

/** Par défaut, personne n'est bloqué. */
function buildModeration(blocked = false): ModerationStub {
  return {
    isBlockedEitherWay: jest.fn().mockResolvedValue(blocked),
    blockedUserIdsEitherWay: jest.fn().mockResolvedValue(new Set<string>(blocked ? [FRIEND] : [])),
  };
}

function buildService(
  stubs: Stubs,
  notifications: NotificationsStub = buildNotifications(),
  moderation: ModerationStub = buildModeration(),
): CommunityService {
  return new CommunityService(
    stubs as unknown as CommunityRepository,
    moderation as unknown as CommunityModerationRepository,
    challengesStub as unknown as CommunityChallengesService,
    notifications as unknown as NotificationsService,
    loggerStub as unknown as PinoLogger,
  );
}

describe('CommunityService — demandes d’ami', () => {
  it('ne révèle JAMAIS si un compte existe : e-mail inconnu = même silence', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.requestFriend(ME, 'inconnu@carlys.test')).resolves.toBeUndefined();
    expect(stubs.createRequest).not.toHaveBeenCalled();
  });

  it('se demander soi-même en ami est ignoré en silence', async () => {
    const stubs = buildStubs();
    stubs.findUserIdByEmail.mockResolvedValue({ id: ME });
    const service = buildService(stubs);

    await service.requestFriend(ME, 'moi@carlys.test');
    expect(stubs.createRequest).not.toHaveBeenCalled();
  });

  it('normalise l’e-mail (majuscules, espaces) avant la recherche', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.requestFriend(ME, '  Ami@Carlys.TEST ');
    expect(stubs.findUserIdByEmail).toHaveBeenCalledWith('ami@carlys.test');
  });

  it('deux demandes croisées deviennent une amitié', async () => {
    const stubs = buildStubs();
    stubs.findUserIdByEmail.mockResolvedValue({ id: FRIEND });
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'demande-1',
      requesterId: FRIEND,
      addresseeId: ME,
      status: FriendRequestStatus.PENDING,
    });
    const service = buildService(stubs);

    await service.requestFriend(ME, 'ami@carlys.test');

    expect(stubs.setRequestStatus).toHaveBeenCalledWith('demande-1', FriendRequestStatus.ACCEPTED);
    expect(stubs.createRequest).not.toHaveBeenCalled();
  });

  it('redemander sa PROPRE demande en attente ne crée pas de doublon', async () => {
    const stubs = buildStubs();
    stubs.findUserIdByEmail.mockResolvedValue({ id: FRIEND });
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'demande-1',
      requesterId: ME,
      addresseeId: FRIEND,
      status: FriendRequestStatus.PENDING,
    });
    const service = buildService(stubs);

    await service.requestFriend(ME, 'ami@carlys.test');

    expect(stubs.createRequest).not.toHaveBeenCalled();
    expect(stubs.setRequestStatus).not.toHaveBeenCalled();
  });

  it('après un refus, le même demandeur reste muet pendant 30 jours', async () => {
    const stubs = buildStubs();
    stubs.findUserIdByEmail.mockResolvedValue({ id: FRIEND });
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'demande-1',
      requesterId: ME,
      addresseeId: FRIEND,
      status: FriendRequestStatus.DECLINED,
      createdAt: new Date(Date.now() - 3 * 24 * 3_600_000),
      respondedAt: new Date(Date.now() - 24 * 3_600_000),
    });
    const notifications = buildNotifications();
    const service = buildService(stubs, notifications);

    // 202 opaque : rien ne bouge en base, rien ne sonne chez l'autre.
    await expect(service.requestFriend(ME, 'ami@carlys.test')).resolves.toBeUndefined();
    expect(stubs.reopenRequest).not.toHaveBeenCalled();
    expect(stubs.setRequestStatus).not.toHaveBeenCalled();
    expect(notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('passé le délai, la demande peut repartir, et l’autre en est notifié', async () => {
    const stubs = buildStubs();
    stubs.findUserIdByEmail.mockResolvedValue({ id: FRIEND });
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'demande-1',
      requesterId: ME,
      addresseeId: FRIEND,
      status: FriendRequestStatus.DECLINED,
      createdAt: new Date(Date.now() - 40 * 24 * 3_600_000),
      respondedAt: new Date(Date.now() - 31 * 24 * 3_600_000),
    });
    const notifications = buildNotifications();
    const service = buildService(stubs, notifications);

    await service.requestFriend(ME, 'ami@carlys.test');

    expect(stubs.reopenRequest).toHaveBeenCalledWith('demande-1', ME, FRIEND);
    expect(notifications.sendToUser).toHaveBeenCalledTimes(1);
  });

  it('celui qui a refusé peut prendre contact : la demande repart dans son sens', async () => {
    const stubs = buildStubs();
    stubs.findUserIdByEmail.mockResolvedValue({ id: FRIEND });
    // FRIEND avait demandé, ME a refusé hier ; ME change d'avis.
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'demande-1',
      requesterId: FRIEND,
      addresseeId: ME,
      status: FriendRequestStatus.DECLINED,
      createdAt: new Date(Date.now() - 2 * 24 * 3_600_000),
      respondedAt: new Date(Date.now() - 24 * 3_600_000),
    });
    const notifications = buildNotifications();
    const service = buildService(stubs, notifications);

    await service.requestFriend(ME, 'ami@carlys.test');

    // Pas de délai pour lui, et c'est LUI qui demande désormais.
    expect(stubs.reopenRequest).toHaveBeenCalledWith('demande-1', ME, FRIEND);
    expect(notifications.sendToUser).toHaveBeenCalledWith(
      FRIEND,
      expect.objectContaining({ title: 'Nouvelle demande d’ami' }),
      'FRIEND_REQUESTS',
    );
  });

  it('seul le DESTINATAIRE peut répondre à une demande', async () => {
    const stubs = buildStubs();
    stubs.findRequestById.mockResolvedValue({
      id: 'demande-1',
      requesterId: ME,
      addresseeId: FRIEND,
      status: FriendRequestStatus.PENDING,
    });
    const service = buildService(stubs);

    // ME est l'expéditeur, pas le destinataire : il ne peut pas s'auto-accepter.
    await expect(service.respondToRequest(ME, 'demande-1', true)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});

describe('CommunityService — code ami', () => {
  it('toutes les formes humaines d’un code mènent au même compte', async () => {
    const stubs = buildStubs();
    stubs.findUserByFriendCode.mockResolvedValue({
      id: FRIEND,
      profile: { displayName: 'Alice' },
    });
    const service = buildService(stubs);

    // Forme affichée, casse relâchée, charge utile de QR : même canonique.
    for (const forme of ['AC23-DEF4', 'ac23def4', 'carlys:friend:AC23DEF4']) {
      await service.requestFriendByCode(ME, forme);
      expect(stubs.findUserByFriendCode).toHaveBeenLastCalledWith('AC23DEF4');
    }
    expect(stubs.createRequest).toHaveBeenCalledTimes(3);
  });

  it('un code mal formé ou inconnu reste aussi muet qu’un e-mail inconnu', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.requestFriendByCode(ME, 'pas-un-code');
    await service.requestFriendByCode(ME, 'AC23DEF4'); // bien formé, inconnu
    expect(stubs.createRequest).not.toHaveBeenCalled();

    // Le code mal formé n'atteint jamais la base : rien à y chercher.
    expect(stubs.findUserByFriendCode).toHaveBeenCalledTimes(1);
  });

  it('scanner son propre QR est ignoré en silence', async () => {
    const stubs = buildStubs();
    stubs.findUserByFriendCode.mockResolvedValue({ id: ME, profile: null });
    const service = buildService(stubs);

    await service.requestFriendByCode(ME, 'AC23DEF4');
    expect(stubs.createRequest).not.toHaveBeenCalled();
  });

  it('l’aperçu d’un code donne le nom — et 404 si personne ne le porte', async () => {
    const stubs = buildStubs();
    stubs.findUserByFriendCode.mockResolvedValue({
      id: FRIEND,
      profile: { displayName: 'Alice' },
    });
    const service = buildService(stubs);

    await expect(service.lookupFriendCode(ME, 'ac23-def4')).resolves.toEqual({
      displayName: 'Alice',
    });

    stubs.findUserByFriendCode.mockResolvedValue(null);
    await expect(service.lookupFriendCode(ME, 'AC23DEF4')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('mon profil communautaire porte mon code ami', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.profile(ME)).resolves.toEqual({
      sharesProgress: true,
      friendCode: 'AC23DEF4',
    });
  });
});

describe('CommunityService — confidentialité des statistiques', () => {
  it('un profil privé sort SANS série ni séances — null, pas zéro', async () => {
    const stubs = buildStubs();
    stubs.listFriends.mockResolvedValue([
      {
        userId: FRIEND,
        displayName: 'Tom',
        timezone: 'Europe/Paris',
        sharesProgress: false,
      },
    ]);
    const service = buildService(stubs);

    const friends = await service.listFriends(ME);

    expect(friends).toEqual([
      {
        userId: FRIEND,
        displayName: 'Tom',
        sharesProgress: false,
        streakDays: null,
        weeklySessions: null,
      },
    ]);
    // La donnée privée n'est même pas LUE : aucune requête de séances.
    expect(stubs.completedSessionStarts).not.toHaveBeenCalled();
  });

  it('un profil partagé reçoit série et séances de la semaine', async () => {
    const stubs = buildStubs();
    stubs.listFriends.mockResolvedValue([
      {
        userId: FRIEND,
        displayName: 'Sarah',
        timezone: 'UTC',
        sharesProgress: true,
      },
    ]);
    const today = new Date();
    stubs.completedSessionStarts.mockResolvedValue([today]);
    const service = buildService(stubs);

    const [friend] = await service.listFriends(ME);

    expect(friend?.streakDays).toBe(1);
    expect(friend?.weeklySessions).toBe(1);
  });
});

describe('CommunityService — encouragements', () => {
  it('refuse d’encourager quelqu’un qui n’est pas un ami accepté', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.encourage(ME, FRIEND, 'Bravo !')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(stubs.createEncouragement).not.toHaveBeenCalled();
  });

  it('écrit chez un ami accepté', async () => {
    const stubs = buildStubs();
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'amitié-1',
      requesterId: FRIEND,
      addresseeId: ME,
      status: FriendRequestStatus.ACCEPTED,
    });
    const service = buildService(stubs);

    await service.encourage(ME, FRIEND, 'Bravo !');
    expect(stubs.createEncouragement).toHaveBeenCalledWith(ME, FRIEND, 'Bravo !');
  });
});

describe('CommunityService — blocages : réponses opaques partout', () => {
  const accepted = {
    id: 'amitié-1',
    requesterId: FRIEND,
    addresseeId: ME,
    status: FriendRequestStatus.ACCEPTED,
  };

  it('une demande vers une personne bloquée (dans un sens ou l’autre) reste muette', async () => {
    const stubs = buildStubs();
    stubs.findUserIdByEmail.mockResolvedValue({ id: FRIEND });
    stubs.findUserByFriendCode.mockResolvedValue({ id: FRIEND, profile: null });
    const notifications = buildNotifications();
    const service = buildService(stubs, notifications, buildModeration(true));

    await expect(service.requestFriend(ME, 'ami@carlys.test')).resolves.toBeUndefined();
    await expect(service.requestFriendByCode(ME, 'AC23DEF4')).resolves.toBeUndefined();

    // Rien n'est même LU sur l'amitié : la réponse est celle d'un inconnu.
    expect(stubs.findFriendshipBetween).not.toHaveBeenCalled();
    expect(stubs.createRequest).not.toHaveBeenCalled();
    expect(notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('l’aperçu du code d’une personne bloquée répond comme un code inconnu', async () => {
    const stubs = buildStubs();
    stubs.findUserByFriendCode.mockResolvedValue({ id: FRIEND, profile: { displayName: 'Tom' } });
    const service = buildService(stubs, buildNotifications(), buildModeration(true));

    await expect(service.lookupFriendCode(ME, 'AC23DEF4')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('encourager une personne bloquée est refusé comme un non-ami (403, pas plus)', async () => {
    const stubs = buildStubs();
    stubs.findFriendshipBetween.mockResolvedValue(accepted);
    const service = buildService(stubs, buildNotifications(), buildModeration(true));

    await expect(service.encourage(ME, FRIEND, 'Bravo !')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(stubs.createEncouragement).not.toHaveBeenCalled();
  });

  it('la liste d’amis et le fil taisent les personnes bloquées', async () => {
    const stubs = buildStubs();
    stubs.listFriends.mockResolvedValue([
      { userId: FRIEND, displayName: 'Tom', timezone: 'UTC', sharesProgress: true },
      { userId: 'utilisateur-tiers', displayName: 'Léa', timezone: 'UTC', sharesProgress: false },
    ]);
    const service = buildService(stubs, buildNotifications(), buildModeration(true));

    const friends = await service.listFriends(ME);
    expect(friends.map((friend) => friend.displayName)).toEqual(['Léa']);

    await service.feed(ME);
    expect(stubs.listEncouragements).toHaveBeenCalledWith(ME, expect.any(Number), [FRIEND]);
  });
});

describe('CommunityService — relais vers les défis', () => {
  it('la clôture de séance est relayée au service des défis, sans autre logique', async () => {
    const service = buildService(buildStubs());
    const at = new Date('2026-08-11T10:00:00Z');

    await service.recordWorkoutCompleted(ME, at);

    expect(challengesStub.recordWorkoutCompleted).toHaveBeenCalledWith(ME, at);
  });
});

describe('CommunityService — notifications push', () => {
  it('une nouvelle demande d’ami notifie le DESTINATAIRE, au nom du demandeur', async () => {
    const stubs = buildStubs();
    stubs.findUserIdByEmail.mockResolvedValue({ id: FRIEND });
    const notifications = buildNotifications();
    const service = buildService(stubs, notifications);

    await service.requestFriend(ME, 'ami@carlys.test');

    expect(stubs.displayNameOf).toHaveBeenCalledWith(ME);
    // La CATÉGORIE voyage jusqu'à l'envoi : c'est elle qui permet de
    // couper les demandes d'ami sans couper les encouragements.
    expect(notifications.sendToUser).toHaveBeenCalledWith(
      FRIEND,
      {
        title: 'Nouvelle demande d’ami',
        body: 'Alice souhaite devenir ton ami.',
      },
      'FRIEND_REQUESTS',
    );
  });

  it('accepter une demande notifie le demandeur ; refuser reste silencieux', async () => {
    const stubs = buildStubs();
    stubs.findRequestById.mockResolvedValue({
      id: 'demande-1',
      requesterId: FRIEND,
      addresseeId: ME,
      status: FriendRequestStatus.PENDING,
    });
    const notifications = buildNotifications();
    const service = buildService(stubs, notifications);

    await service.respondToRequest(ME, 'demande-1', false);
    expect(notifications.sendToUser).not.toHaveBeenCalled();

    await service.respondToRequest(ME, 'demande-1', true);
    expect(notifications.sendToUser).toHaveBeenCalledWith(
      FRIEND,
      {
        title: 'Demande acceptée',
        body: 'Alice a accepté ta demande d’ami.',
      },
      'FRIEND_REQUESTS',
    );
  });

  it('un encouragement pousse le message chez l’ami', async () => {
    const stubs = buildStubs();
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'amitié-1',
      requesterId: FRIEND,
      addresseeId: ME,
      status: FriendRequestStatus.ACCEPTED,
    });
    const notifications = buildNotifications();
    const service = buildService(stubs, notifications);

    await service.encourage(ME, FRIEND, 'Bravo pour ta série !');

    expect(notifications.sendToUser).toHaveBeenCalledWith(
      FRIEND,
      {
        title: 'Encouragement de Alice',
        body: 'Bravo pour ta série !',
      },
      'ENCOURAGEMENTS',
    );
  });

  it('push désactivé : aucun nom n’est lu, aucun envoi tenté', async () => {
    const stubs = buildStubs();
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'amitié-1',
      requesterId: FRIEND,
      addresseeId: ME,
      status: FriendRequestStatus.ACCEPTED,
    });
    const notifications = buildNotifications(false);
    const service = buildService(stubs, notifications);

    await service.encourage(ME, FRIEND, 'Bravo !');

    expect(stubs.displayNameOf).not.toHaveBeenCalled();
    expect(notifications.sendToUser).not.toHaveBeenCalled();
  });

  it('un échec de notification ne fait JAMAIS échouer le flux métier', async () => {
    const stubs = buildStubs();
    stubs.displayNameOf.mockRejectedValue(new Error('base indisponible'));
    stubs.findFriendshipBetween.mockResolvedValue({
      id: 'amitié-1',
      requesterId: FRIEND,
      addresseeId: ME,
      status: FriendRequestStatus.ACCEPTED,
    });
    const service = buildService(stubs);

    await expect(service.encourage(ME, FRIEND, 'Bravo !')).resolves.toBeUndefined();
    expect(loggerStub.error).toHaveBeenCalled();
  });
});
