import { NotFoundException } from '@nestjs/common';
import { type PinoLogger } from 'nestjs-pino';
import { type CommunityChallengesRepository } from '../infrastructure/community-challenges.repository';
import { CommunityChallengesService } from './community-challenges.service';

const ME = 'utilisateur-moi';
const FRIEND = 'utilisateur-ami';

interface Stubs {
  listOpenChallenges: jest.Mock;
  findChallengeById: jest.Mock;
  joinChallenge: jest.Mock;
  leaveChallenge: jest.Mock;
  challengeStats: jest.Mock;
  incrementSportContributions: jest.Mock;
  createQuizAnswer: jest.Mock;
  incrementCultureContributions: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    listOpenChallenges: jest.fn().mockResolvedValue([]),
    findChallengeById: jest.fn().mockResolvedValue(null),
    joinChallenge: jest.fn().mockResolvedValue(undefined),
    leaveChallenge: jest.fn().mockResolvedValue(undefined),
    challengeStats: jest.fn().mockResolvedValue(null),
    incrementSportContributions: jest.fn().mockResolvedValue(undefined),
    createQuizAnswer: jest.fn().mockResolvedValue(true),
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

describe('CommunityChallengesService — réponses de quiz (défis CULTURE)', () => {
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
