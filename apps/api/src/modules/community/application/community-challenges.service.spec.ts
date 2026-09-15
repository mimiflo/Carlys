import { NotFoundException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { MONTHLY_CHALLENGE_CATALOG, type MonthlyChallengeSeed } from '../domain/challenge-catalog';
import { type CommunityChallengesRepository } from '../infrastructure/community-challenges.repository';
import { CommunityChallengesService } from './community-challenges.service';

const ME = 'utilisateur-moi';
const FRIEND = 'utilisateur-ami';

interface Stubs {
  countForMonth: jest.Mock;
  createMonthlyChallenges: jest.Mock;
  listOpenChallenges: jest.Mock;
  findChallengeById: jest.Mock;
  joinChallenge: jest.Mock;
  leaveChallenge: jest.Mock;
  challengeStats: jest.Mock;
  incrementSportContributions: jest.Mock;
  recordQuizAnswer: jest.Mock;
  incrementCultureContributions: jest.Mock;
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
    incrementSportContributions: jest.fn().mockResolvedValue(undefined),
    recordQuizAnswer: jest.fn().mockResolvedValue(true),
    incrementCultureContributions: jest.fn().mockResolvedValue(undefined),
  };
}

const loggerStub = { error: jest.fn() };

function buildService(stubs: Stubs): CommunityChallengesService {
  return new CommunityChallengesService(
    stubs as unknown as CommunityChallengesRepository,
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
    });
    expect(stubs.incrementCultureContributions).not.toHaveBeenCalled();
  });
});
