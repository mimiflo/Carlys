import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { FriendRequestStatus } from '@prisma/client';
import { type PinoLogger } from 'nestjs-pino';
import { type NotificationsService } from '../../notifications/application/notifications.service';
import { type CommunityRepository } from '../infrastructure/community.repository';
import { CommunityService } from './community.service';

const ME = 'utilisateur-moi';
const FRIEND = 'utilisateur-ami';

interface Stubs {
  displayNameOf: jest.Mock;
  createQuizAnswer: jest.Mock;
  incrementCultureContributions: jest.Mock;
  findFriendshipBetween: jest.Mock;
  createRequest: jest.Mock;
  findRequestById: jest.Mock;
  setRequestStatus: jest.Mock;
  deleteFriendship: jest.Mock;
  listReceivedRequests: jest.Mock;
  listFriends: jest.Mock;
  findUserIdByEmail: jest.Mock;
  completedSessionStarts: jest.Mock;
  listEncouragements: jest.Mock;
  createEncouragement: jest.Mock;
  listOpenChallenges: jest.Mock;
  findChallengeById: jest.Mock;
  joinChallenge: jest.Mock;
  leaveChallenge: jest.Mock;
  challengeStats: jest.Mock;
  incrementSportContributions: jest.Mock;
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
    deleteFriendship: jest.fn().mockResolvedValue(undefined),
    listReceivedRequests: jest.fn().mockResolvedValue([]),
    listFriends: jest.fn().mockResolvedValue([]),
    findUserIdByEmail: jest.fn().mockResolvedValue(null),
    completedSessionStarts: jest.fn().mockResolvedValue([]),
    listEncouragements: jest.fn().mockResolvedValue([]),
    createEncouragement: jest.fn().mockResolvedValue({}),
    listOpenChallenges: jest.fn().mockResolvedValue([]),
    findChallengeById: jest.fn().mockResolvedValue(null),
    joinChallenge: jest.fn().mockResolvedValue(undefined),
    leaveChallenge: jest.fn().mockResolvedValue(undefined),
    challengeStats: jest.fn().mockResolvedValue(null),
    incrementSportContributions: jest.fn().mockResolvedValue(undefined),
    createQuizAnswer: jest.fn().mockResolvedValue(true),
    incrementCultureContributions: jest.fn().mockResolvedValue(undefined),
    sharesProgress: jest.fn().mockResolvedValue(true),
    setSharesProgress: jest.fn().mockResolvedValue(undefined),
  };
}

const loggerStub = { error: jest.fn() };

interface NotificationsStub {
  pushEnabled: boolean;
  sendToUser: jest.Mock;
}

function buildNotifications(pushEnabled = true): NotificationsStub {
  return { pushEnabled, sendToUser: jest.fn().mockResolvedValue(undefined) };
}

function buildService(
  stubs: Stubs,
  notifications: NotificationsStub = buildNotifications(),
): CommunityService {
  return new CommunityService(
    stubs as unknown as CommunityRepository,
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

describe('CommunityService — défis collectifs', () => {
  const challenge = {
    id: 'defi-1',
    slug: 'defi-1',
    kind: 'SPORT' as const,
    title: 'Défi',
    description: '…',
    target: 10,
    startsAt: new Date('2026-08-01T00:00:00Z'),
    endsAt: new Date('2100-01-01T00:00:00Z'),
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  it('la progression est collective, bornée à 1', async () => {
    const stubs = buildStubs();
    stubs.listOpenChallenges.mockResolvedValue([
      {
        ...challenge,
        participations: [
          { userId: ME, contribution: 8 },
          { userId: FRIEND, contribution: 7 },
        ],
      },
    ]);
    const service = buildService(stubs);

    const [presented] = await service.listChallenges(ME);

    expect(presented?.progress).toBe(1); // 15/10, borné.
    expect(presented?.participants).toBe(2);
    expect(presented?.joined).toBe(true);
  });

  it('un objectif nul ne divise pas par zéro', async () => {
    const stubs = buildStubs();
    stubs.listOpenChallenges.mockResolvedValue([{ ...challenge, target: 0, participations: [] }]);
    const service = buildService(stubs);

    const [presented] = await service.listChallenges(ME);
    expect(presented?.progress).toBe(0);
  });

  it('rejoindre un défi terminé est refusé', async () => {
    const stubs = buildStubs();
    stubs.findChallengeById.mockResolvedValue({
      ...challenge,
      endsAt: new Date('2020-01-01T00:00:00Z'),
    });
    const service = buildService(stubs);

    await expect(service.joinChallenge(ME, 'defi-1')).rejects.toBeInstanceOf(NotFoundException);
    expect(stubs.joinChallenge).not.toHaveBeenCalled();
  });

  it('la contribution de séance n’échoue JAMAIS bruyamment', async () => {
    const stubs = buildStubs();
    stubs.incrementSportContributions.mockRejectedValue(new Error('base indisponible'));
    const service = buildService(stubs);

    await expect(service.recordWorkoutCompleted(ME, new Date())).resolves.toBeUndefined();
    expect(loggerStub.error).toHaveBeenCalled();
  });
});

describe('CommunityService — réponses de quiz (défis CULTURE)', () => {
  const answer = { lessonId: 'lecon-dos', answeredOn: '2026-08-11', correct: true };

  it('une première réponse JUSTE contribue aux défis culturels', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.recordQuizAnswer(ME, answer);

    expect(stubs.createQuizAnswer).toHaveBeenCalledWith({ userId: ME, ...answer });
    expect(stubs.incrementCultureContributions).toHaveBeenCalledTimes(1);
  });

  it('un rejeu (réponse déjà comptée) ne contribue pas deux fois', async () => {
    const stubs = buildStubs();
    stubs.createQuizAnswer.mockResolvedValue(false);
    const service = buildService(stubs);

    await service.recordQuizAnswer(ME, answer);

    expect(stubs.incrementCultureContributions).not.toHaveBeenCalled();
  });

  it('une réponse fausse est enregistrée mais ne contribue pas', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.recordQuizAnswer(ME, { ...answer, correct: false });

    expect(stubs.createQuizAnswer).toHaveBeenCalled();
    expect(stubs.incrementCultureContributions).not.toHaveBeenCalled();
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
