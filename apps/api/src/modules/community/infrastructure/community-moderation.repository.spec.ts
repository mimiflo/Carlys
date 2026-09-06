import { type PrismaService } from '../../../database/prisma/prisma.service';
import { CommunityModerationRepository } from './community-moderation.repository';

const REPORTER = 'utilisateur-signalant';
const REPORTED = 'utilisateur-signale';

interface FakeTransaction {
  encouragement: { findFirst: jest.Mock };
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

function buildTransaction(message: string | null): FakeTransaction {
  return {
    encouragement: {
      findFirst: jest.fn().mockResolvedValue(message === null ? null : { message }),
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
  reason: 'HARCELEMENT' as const,
  details: null,
};

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
    expect(tx.communityReport.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { ...input, encouragementId: null, encouragementMessage: null },
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
