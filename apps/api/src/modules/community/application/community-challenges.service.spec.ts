import { NotFoundException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { MONTHLY_CHALLENGE_CATALOG, type MonthlyChallengeSeed } from '../domain/challenge-catalog';
import { type CommunityChallengesRepository } from '../infrastructure/community-challenges.repository';
import { type FriendChallengesRepository } from '../infrastructure/friend-challenges.repository';
import { CommunityChallengesService } from './community-challenges.service';
import { type LeaguesService } from './leagues.service';

const ME = 'utilisateur-moi';

interface Stubs {
  countForMonth: jest.Mock;
  createMonthlyChallenges: jest.Mock;
  listOpenChallenges: jest.Mock;
  findChallengeById: jest.Mock;
  joinChallenge: jest.Mock;
  leaveChallenge: jest.Mock;
  challengeStats: jest.Mock;
  contribute: jest.Mock;
  recordQuizAnswer: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    // Par défaut, le mois est déjà servi : la lecture ne crée rien.
    countForMonth: jest.fn().mockResolvedValue(MONTHLY_CHALLENGE_CATALOG.length),
    createMonthlyChallenges: jest.fn().mockResolvedValue(undefined),
    listOpenChallenges: jest.fn().mockResolvedValue([]),
    findChallengeById: jest.fn().mockResolvedValue(null),
    joinChallenge: jest.fn().mockResolvedValue(undefined),
    leaveChallenge: jest.fn().mockResolvedValue(undefined),
    challengeStats: jest.fn().mockResolvedValue(null),
    contribute: jest.fn().mockResolvedValue(undefined),
    recordQuizAnswer: jest.fn().mockResolvedValue(true),
  };
}

const loggerStub = { error: jest.fn() };

/**
 * Les défis ENTRE AMIS reçoivent la même chose que les collectifs : la
 * doublure existe pour que les épreuves ci-dessous continuent de porter sur
 * UN chemin, et un test dédié vérifie qu'ils reçoivent bien les deux.
 */
const friendStub = { contribute: jest.fn().mockResolvedValue(undefined) };

/**
 * La LIGUE reçoit par la même couture, et sa doublure existe pour la même
 * raison : le barème (`league-ladder.spec.ts`) et le versement (e2e) sont
 * éprouvés ailleurs, chacun sur son terrain.
 */
const leagueStub = { contribute: jest.fn().mockResolvedValue(undefined) };

function buildService(stubs: Stubs): CommunityChallengesService {
  friendStub.contribute.mockClear();
  leagueStub.contribute.mockClear();
  return new CommunityChallengesService(
    stubs as unknown as CommunityChallengesRepository,
    friendStub as unknown as FriendChallengesRepository,
    leagueStub as unknown as LeaguesService,
    loggerStub as unknown as PinoLogger,
  );
}

describe('CommunityChallengesService — défis collectifs', () => {
  const challenge = {
    id: 'defi-1',
    slug: 'defi-1',
    month: '2026-08',
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
      // Le dépôt agrège désormais en base : le service reçoit les trois
      // scalaires, il ne parcourt plus une liste de participants.
      { ...challenge, totalContribution: 15, participants: 2, joined: true },
    ]);
    const service = buildService(stubs);

    const [presented] = await service.listChallenges(ME);

    expect(presented?.progress).toBe(1); // 15/10, borné.
    expect(presented?.participants).toBe(2);
    expect(presented?.joined).toBe(true);
  });

  it('un objectif nul ne divise pas par zéro', async () => {
    const stubs = buildStubs();
    stubs.listOpenChallenges.mockResolvedValue([
      { ...challenge, target: 0, totalContribution: 0, participants: 0, joined: false },
    ]);
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
    stubs.contribute.mockRejectedValue(new Error('base indisponible'));
    const service = buildService(stubs);

    await expect(
      service.recordWorkoutCompleted(ME, new Date(), {
        activeSeconds: 0,
        distanceMeters: 0,
      }),
    ).resolves.toBeUndefined();
    expect(loggerStub.error).toHaveBeenCalled();
  });

  it('une séance verse à TROIS métriques : séance, secondes, mètres', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);
    const at = new Date('2026-09-15T12:00:00.000Z');

    await service.recordWorkoutCompleted(ME, at, {
      activeSeconds: 1_800,
      distanceMeters: 5_000,
    });

    // Le même fait alimente les défis qui comptent des séances ET ceux qui
    // comptent des kilomètres : c'est tout l'objet de la généralisation.
    expect(stubs.contribute.mock.calls.map((call: unknown[]) => call.slice(1, 3))).toEqual([
      ['WORKOUTS', 1],
      ['ACTIVE_SECONDS', 1_800],
      ['DISTANCE_METERS', 5_000],
    ]);
  });
});

describe('CommunityChallengesService — défis du mois, création paresseuse', () => {
  it('un mois sans défi reçoit le catalogue à la première lecture, AVANT de lister', async () => {
    const stubs = buildStubs();
    stubs.countForMonth.mockResolvedValue(0);
    const order: string[] = [];
    stubs.createMonthlyChallenges.mockImplementation(() => {
      order.push('create');
      return Promise.resolve();
    });
    stubs.listOpenChallenges.mockImplementation(() => {
      order.push('list');
      return Promise.resolve([]);
    });
    const service = buildService(stubs);

    await service.listChallenges(ME);

    expect(order).toEqual(['create', 'list']);
    const [seeds] = stubs.createMonthlyChallenges.mock.calls[0] as [MonthlyChallengeSeed[]];
    expect(seeds.map((seed) => seed.slug)).toEqual(
      MONTHLY_CHALLENGE_CATALOG.map((template) => template.slug),
    );
    expect(stubs.countForMonth).toHaveBeenCalledWith(
      seeds[0]?.month,
      MONTHLY_CHALLENGE_CATALOG.map((template) => template.slug),
    );
  });

  it('un catalogue enrichi en cours de mois : ce qui manque est écrit, le reste est ignoré', async () => {
    const stubs = buildStubs();
    stubs.countForMonth.mockResolvedValue(MONTHLY_CHALLENGE_CATALOG.length - 1);
    const service = buildService(stubs);

    await service.listChallenges(ME);

    // Tout le jeu est renvoyé : skipDuplicates n'écrit que les absents.
    expect(stubs.createMonthlyChallenges).toHaveBeenCalledTimes(1);
  });

  it('un mois déjà servi ne recrée rien : un comptage, et c’est tout', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.listChallenges(ME);

    expect(stubs.countForMonth).toHaveBeenCalledTimes(1);
    expect(stubs.createMonthlyChallenges).not.toHaveBeenCalled();
  });
});

describe('CommunityChallengesService — réponses de quiz (défis CULTURE)', () => {
  const answer = { lessonId: 'lecon-dos', answeredOn: '2026-08-11', correct: true };

  it('les deux écritures partent ENSEMBLE, jamais l’une puis l’autre', async () => {
    // Le service décidait lui-même d'incrémenter APRÈS l'écriture de la
    // réponse. Un échec entre les deux laissait la réponse seule, et
    // l'unicité rendait la perte définitive : au rejeu, « déjà comptée »,
    // l'incrément jamais retenté. Le choix appartient désormais au dépôt,
    // qui peut les tenir dans une transaction ; ce que le service doit
    // garantir, c'est de ne PAS les séparer.
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.recordQuizAnswer(ME, answer);

    expect(stubs.recordQuizAnswer).toHaveBeenCalledWith({
      userId: ME,
      ...answer,
      at: expect.any(Date) as Date,
      // La contribution aux défis entre amis part DANS la transaction du
      // dépôt, sous forme de fonction : écrite à côté, son échec laisserait
      // la réponse seule, et l'unicité rendrait la perte définitive.
      alsoInTransaction: expect.any(Function) as () => Promise<void>,
    });
    // La contribution part DANS la transaction du dépôt, jamais à côté :
    // séparées, l'échec de la seconde écriture laissait la première, et
    // l'unicité rendait la perte définitive au rejeu.
    expect(stubs.contribute).not.toHaveBeenCalled();
  });
});
