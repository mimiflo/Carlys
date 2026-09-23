import { type PrismaService } from '../../../database/prisma/prisma.service';
import { CommunityModerationRepository } from './community-moderation.repository';

const REPORTER = 'utilisateur-signalant';
const REPORTED = 'utilisateur-signale';

interface FakeTransaction {
  encouragement: { findFirst: jest.Mock };
  friendChallenge: { findFirst: jest.Mock };
  communityReport: { create: jest.Mock };
}

/**
 * Prisma factice réduit à la transaction interactive : le rappel reçoit un
 * client de transaction dont on observe les deux appels. Rien d'autre du
 * dépôt n'est simulé ici, le reste est couvert par les e2e.
 */
function buildPrisma(tx: FakeTransaction): PrismaService {
  return {
    $transaction: jest.fn((run: (client: FakeTransaction) => Promise<unknown>) => run(tx)),
  } as unknown as PrismaService;
}

function buildTransaction(
  message: string | null,
  challenge: { title: string; message: string | null } | null = null,
): FakeTransaction {
  return {
    encouragement: {
      findFirst: jest.fn().mockResolvedValue(message === null ? null : { message }),
    },
    friendChallenge: {
      findFirst: jest.fn().mockResolvedValue(challenge),
    },
    communityReport: {
      create: jest
        .fn()
        .mockImplementation(({ data }: { data: Record<string, unknown> }) =>
          Promise.resolve({ id: 'signalement-1', ...data }),
        ),
    },
  };
}

const input = {
  reporterId: REPORTER,
  reportedUserId: REPORTED,
  friendChallengeId: null,
  reason: 'HARCELEMENT' as const,
  details: null,
};

/** Aucun défi visé : ses deux clichés restent vides. */
const NO_CHALLENGE_SNAPSHOT = { friendChallengeTitle: null, friendChallengeMessage: null };

describe('CommunityModerationRepository.createReport — cliché du texte signalé', () => {
  it('fige le texte de l’encouragement visé, lu dans la même transaction', async () => {
    const tx = buildTransaction('Réponds-moi tout de suite.');
    const repository = new CommunityModerationRepository(buildPrisma(tx));

    const created = await repository.createReport({ ...input, encouragementId: 'message-1' });

    // Seul ce que le signalant a REÇU de la personne signalée est lu.
    expect(tx.encouragement.findFirst).toHaveBeenCalledWith({
      where: { id: 'message-1', senderId: REPORTED, recipientId: REPORTER },
      select: { message: true },
    });
    // Les données écrites sont EXACTEMENT l'entrée, plus le cliché.
    expect(tx.communityReport.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: {
          ...input,
          ...NO_CHALLENGE_SNAPSHOT,
          encouragementId: 'message-1',
          encouragementMessage: 'Réponds-moi tout de suite.',
        },
      }),
    );
    expect(created).toMatchObject({ encouragementMessage: 'Réponds-moi tout de suite.' });
  });

  it('sans encouragement visé, rien n’est lu et le cliché reste vide', async () => {
    const tx = buildTransaction(null);
    const repository = new CommunityModerationRepository(buildPrisma(tx));

    await repository.createReport({ ...input, encouragementId: null });

    expect(tx.encouragement.findFirst).not.toHaveBeenCalled();
    expect(tx.friendChallenge.findFirst).not.toHaveBeenCalled();
    expect(tx.communityReport.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: {
          ...input,
          ...NO_CHALLENGE_SNAPSHOT,
          encouragementId: null,
          encouragementMessage: null,
        },
      }),
    );
  });

  it('un encouragement introuvable entre ces deux personnes n’écrit rien : null', async () => {
    const tx = buildTransaction(null);
    const repository = new CommunityModerationRepository(buildPrisma(tx));

    await expect(
      repository.createReport({ ...input, encouragementId: 'message-etranger' }),
    ).resolves.toBeNull();
    expect(tx.communityReport.create).not.toHaveBeenCalled();
  });
});

describe('CommunityModerationRepository.createReport — cliché du défi signalé', () => {
  const challengeInput = { ...input, encouragementId: null, friendChallengeId: 'defi-1' };

  it('fige le titre et le message du défi, lus dans la même transaction', async () => {
    const tx = buildTransaction(null, { title: 'Qui court le plus', message: 'On verra.' });
    const repository = new CommunityModerationRepository(buildPrisma(tx));

    const created = await repository.createReport(challengeInput);

    // Un défi dont le signalant est MEMBRE (tout statut) et dont la personne
    // signalée est la CRÉATRICE : une seule lecture, un seul refus possible.
    expect(tx.friendChallenge.findFirst).toHaveBeenCalledWith({
      where: {
        id: 'defi-1',
        creatorId: REPORTED,
        members: { some: { userId: REPORTER } },
      },
      select: { title: true, message: true },
    });
    expect(tx.encouragement.findFirst).not.toHaveBeenCalled();
    expect(tx.communityReport.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: {
          ...challengeInput,
          encouragementMessage: null,
          friendChallengeTitle: 'Qui court le plus',
          friendChallengeMessage: 'On verra.',
        },
      }),
    );
    expect(created).toMatchObject({ friendChallengeTitle: 'Qui court le plus' });
  });

  it('un défi sans message fige son titre seul', async () => {
    const tx = buildTransaction(null, { title: 'Dix séances', message: null });
    const repository = new CommunityModerationRepository(buildPrisma(tx));

    await repository.createReport(challengeInput);

    expect(tx.communityReport.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          friendChallengeTitle: 'Dix séances',
          friendChallengeMessage: null,
        }) as unknown,
      }),
    );
  });

  it('un défi introuvable pour ce couple (inconnu, non-membre, autre créateur) n’écrit rien : null', async () => {
    const tx = buildTransaction(null, null);
    const repository = new CommunityModerationRepository(buildPrisma(tx));

    await expect(repository.createReport(challengeInput)).resolves.toBeNull();
    expect(tx.communityReport.create).not.toHaveBeenCalled();
  });
});
