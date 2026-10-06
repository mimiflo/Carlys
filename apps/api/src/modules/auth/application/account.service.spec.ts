import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { type AuditService } from '../../audit/audit.service';
import { type CommunityWithdrawalService } from '../../community/application/community-withdrawal.service';
import { type MealPhotosService } from '../../nutrition/application/meal-photos.service';
import {
  type AccountBillingService,
  BILLING_NOT_STOPPED,
} from '../../subscriptions/application/account-billing.service';
import { type UsersRepository } from '../../users/infrastructure/users.repository';
import { type SessionsRepository } from '../infrastructure/sessions.repository';
import { AccountService } from './account.service';
import { type LockoutService } from './lockout.service';
import { type PasswordService } from './password.service';
import { ReauthenticationService } from './reauthentication.service';

interface Stubs {
  users: { findPasswordHash: jest.Mock; deleteAccount: jest.Mock; findActiveById: jest.Mock };
  sessions: { deleteAllSessions: jest.Mock; forgetCachedSessions: jest.Mock };
  passwords: { verify: jest.Mock };
  lockout: { reserveAttempt: jest.Mock; reset: jest.Mock };
  audit: { record: jest.Mock };
  mealPhotos: { forgetAllOf: jest.Mock; eraseAllOf: jest.Mock };
  billing: { plan: jest.Mock; stop: jest.Mock; markStopped: jest.Mock };
  community: { withdraw: jest.Mock };
}

function buildStubs(): Stubs {
  return {
    users: {
      findPasswordHash: jest.fn().mockResolvedValue('$argon2id$reel'),
      deleteAccount: jest.fn().mockResolvedValue(undefined),
      findActiveById: jest.fn().mockResolvedValue({ id: 'user-1', email: 'lea@exemple.fr' }),
    },
    sessions: {
      deleteAllSessions: jest.fn().mockResolvedValue(undefined),
      forgetCachedSessions: jest.fn().mockResolvedValue(undefined),
    },
    passwords: { verify: jest.fn().mockResolvedValue(true) },
    lockout: {
      reserveAttempt: jest.fn().mockResolvedValue({ locked: false }),
      reset: jest.fn().mockResolvedValue(undefined),
    },
    audit: { record: jest.fn() },
    mealPhotos: {
      forgetAllOf: jest.fn().mockResolvedValue(undefined),
      eraseAllOf: jest.fn().mockResolvedValue(undefined),
    },
    billing: {
      plan: jest.fn().mockResolvedValue({ stripe: [], storeSubscriptionStillActive: false }),
      stop: jest.fn().mockResolvedValue([]),
      markStopped: jest.fn().mockResolvedValue(undefined),
    },
    community: { withdraw: jest.fn().mockResolvedValue(undefined) },
  };
}

function buildService(stubs: Stubs): AccountService {
  return new AccountService(
    stubs.users as unknown as UsersRepository,
    stubs.sessions as unknown as SessionsRepository,
    new ReauthenticationService(
      stubs.passwords as unknown as PasswordService,
      stubs.lockout as unknown as LockoutService,
    ),
    stubs.audit as unknown as AuditService,
    stubs.mealPhotos as unknown as MealPhotosService,
    stubs.billing as unknown as AccountBillingService,
    stubs.community as unknown as CommunityWithdrawalService,
  );
}

/** Le dépôt qui ouvre la transaction : note l'ordre, passe un client marqué. */
function transactionTracee(stubs: Stubs, order: string[]): Prisma.TransactionClient {
  const tx = { marqueur: 'transaction' } as unknown as Prisma.TransactionClient;
  stubs.users.deleteAccount.mockImplementation(
    async (_userId: string, callback: (client: Prisma.TransactionClient) => Promise<void>) => {
      order.push('transaction ouverte');
      await callback(tx);
      order.push('transaction validée');
    },
  );
  return tx;
}

const client = { ipAddress: '127.0.0.1' };

describe('AccountService', () => {
  it('mot de passe erroné : 401, audit, et rien n’est supprimé', async () => {
    const stubs = buildStubs();
    stubs.passwords.verify.mockResolvedValue(false);
    const service = buildService(stubs);

    await expect(service.deleteAccount('user-1', 'mauvais', client)).rejects.toThrow(
      UnauthorizedException,
    );
    expect(stubs.users.deleteAccount).not.toHaveBeenCalled();
    expect(stubs.sessions.deleteAllSessions).not.toHaveBeenCalled();
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'account.delete_failed', userId: 'user-1' }),
    );
  });

  it('verrouillage de re-authentification : 429 avant toute vérification, rien n’est supprimé', async () => {
    const stubs = buildStubs();
    stubs.lockout.reserveAttempt.mockResolvedValue({ locked: true, retryAfterSeconds: 300 });
    const service = buildService(stubs);

    await expect(service.deleteAccount('user-1', 'juste', client)).rejects.toMatchObject({
      status: 429,
    });
    expect(stubs.lockout.reserveAttempt).toHaveBeenCalledWith('reauth:user-1');
    expect(stubs.passwords.verify).not.toHaveBeenCalled();
    expect(stubs.users.deleteAccount).not.toHaveBeenCalled();
  });

  it('compte SANS mot de passe (Apple/Google) : refus, mais on dit lequel', async () => {
    // Répondre « mot de passe incorrect » à quelqu'un qui n'en a jamais eu
    // l'enverrait chercher indéfiniment : son droit à l'effacement devient
    // inatteignable. Le 409 nomme le chemin qui marche.
    const stubs = buildStubs();
    stubs.users.findPasswordHash.mockResolvedValue(null);
    const service = buildService(stubs);

    await expect(service.deleteAccount('user-1', 'x', client)).rejects.toThrow(ConflictException);
    await expect(service.deleteAccount('user-1', 'x', client)).rejects.toThrow(
      /Mot de passe oublié/,
    );
    // Et surtout : rien n'est supprimé sans preuve.
    expect(stubs.passwords.verify).not.toHaveBeenCalled();
    expect(stubs.users.deleteAccount).not.toHaveBeenCalled();
  });

  it('nominal : la suppression des sessions s’exécute DANS la transaction de suppression', async () => {
    const stubs = buildStubs();
    // Le dépôt des utilisateurs ouvre la transaction et confie son client à
    // la suppression des sessions : c'est ce qui rend l'ensemble atomique.
    let within: ((tx: Prisma.TransactionClient) => Promise<void>) | undefined;
    stubs.users.deleteAccount.mockImplementation(
      (_userId: string, callback: (tx: Prisma.TransactionClient) => Promise<void>) => {
        within = callback;
        return Promise.resolve();
      },
    );
    const service = buildService(stubs);

    await service.deleteAccount('user-1', 'correct', client);

    expect(stubs.users.deleteAccount).toHaveBeenCalledWith('user-1', expect.any(Function));
    if (within === undefined) {
      throw new Error('Le rappel de transaction devait être transmis au dépôt.');
    }
    const tx = { marqueur: 'transaction' } as unknown as Prisma.TransactionClient;
    await within(tx);
    expect(stubs.sessions.deleteAllSessions).toHaveBeenCalledWith('user-1', tx);
    // Le cache du garde JWT oublie les sessions APRÈS le commit.
    expect(stubs.sessions.forgetCachedSessions).toHaveBeenCalledWith('user-1');
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'account.deleted', userId: 'user-1' }),
    );
  });

  it('efface les photos de repas : les lignes DANS la transaction, les objets APRÈS', async () => {
    const stubs = buildStubs();
    const order: string[] = [];
    stubs.users.deleteAccount.mockImplementation(
      async (_userId: string, callback: (tx: Prisma.TransactionClient) => Promise<void>) => {
        order.push('transaction ouverte');
        await callback({ marqueur: 'transaction' } as unknown as Prisma.TransactionClient);
        order.push('transaction validée');
      },
    );
    stubs.mealPhotos.forgetAllOf.mockImplementation(() => {
      order.push('lignes des photos');
      return Promise.resolve();
    });
    stubs.mealPhotos.eraseAllOf.mockImplementation(() => {
      order.push('objets des photos');
      return Promise.resolve();
    });
    const service = buildService(stubs);

    await service.deleteAccount('user-1', 'correct', { ...client, requestId: 'requete-7' });

    // S3 n'est pas transactionnel : effacer les objets AVANT la validation
    // laisserait, si la transaction échouait, un compte vivant aux photos
    // perdues. Après, le pire est un orphelin journalisé et rattrapable.
    expect(order).toEqual([
      'transaction ouverte',
      'lignes des photos',
      'transaction validée',
      'objets des photos',
    ]);
    expect(stubs.mealPhotos.forgetAllOf).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({ marqueur: 'transaction' }),
    );
    expect(stubs.mealPhotos.eraseAllOf).toHaveBeenCalledWith('user-1', 'requete-7');
  });

  it('mot de passe erroné : aucune photo n’est touchée', async () => {
    const stubs = buildStubs();
    stubs.passwords.verify.mockResolvedValue(false);
    const service = buildService(stubs);

    await expect(service.deleteAccount('user-1', 'mauvais', client)).rejects.toThrow(
      UnauthorizedException,
    );
    expect(stubs.mealPhotos.forgetAllOf).not.toHaveBeenCalled();
    expect(stubs.mealPhotos.eraseAllOf).not.toHaveBeenCalled();
  });

  it('résilie Stripe AVANT la transaction, puis marque, retire et rend le signal du magasin', async () => {
    const stubs = buildStubs();
    const order: string[] = [];
    const tx = transactionTracee(stubs, order);
    const plan = {
      stripe: [{ id: 's1', externalSubscriptionId: 'sub_1' }],
      storeSubscriptionStillActive: true,
    };
    stubs.billing.plan.mockResolvedValue(plan);
    stubs.billing.stop.mockImplementation(() => {
      order.push('Stripe résilié');
      return Promise.resolve(['s1']);
    });
    const service = buildService(stubs);

    const resultat = await service.deleteAccount('user-1', 'correct', {
      ...client,
      requestId: 'r-1',
    });

    expect(resultat).toEqual({ storeSubscriptionStillActive: true });
    expect(order).toEqual(['Stripe résilié', 'transaction ouverte', 'transaction validée']);
    expect(stubs.billing.stop).toHaveBeenCalledWith(plan, 'r-1');
    expect(stubs.billing.markStopped).toHaveBeenCalledWith(['s1'], tx);
    expect(stubs.community.withdraw).toHaveBeenCalledWith('user-1', tx);
  });

  it('Stripe n’a pas résilié : 503 écrit pour la personne, RIEN n’est supprimé', async () => {
    const stubs = buildStubs();
    stubs.billing.stop.mockRejectedValue(new UserFacingUnavailableException(BILLING_NOT_STOPPED));
    const service = buildService(stubs);

    await expect(service.deleteAccount('user-1', 'correct', client)).rejects.toThrow(
      BILLING_NOT_STOPPED,
    );
    expect(stubs.users.deleteAccount).not.toHaveBeenCalled();
    expect(stubs.mealPhotos.eraseAllOf).not.toHaveBeenCalled();
    expect(stubs.audit.record).not.toHaveBeenCalledWith(
      expect.objectContaining({ action: 'account.deleted' }),
    );
  });

  it('mot de passe erroné : aucun abonnement n’est touché', async () => {
    const stubs = buildStubs();
    stubs.passwords.verify.mockResolvedValue(false);
    const service = buildService(stubs);

    await expect(service.deleteAccount('user-1', 'mauvais', client)).rejects.toThrow(
      UnauthorizedException,
    );
    expect(stubs.billing.stop).not.toHaveBeenCalled();
  });

  it('effacement par l’exploitation : le MÊME chemin, audité comme tel', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.deleteVerified('user-1', { requestId: 'cli-1' }, 'operator');

    expect(stubs.passwords.verify).not.toHaveBeenCalled();
    expect(stubs.billing.stop).toHaveBeenCalled();
    expect(stubs.users.deleteAccount).toHaveBeenCalled();
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'account.deleted_by_operator',
        actorType: 'SYSTEM',
        userId: 'user-1',
        requestId: 'cli-1',
      }),
    );
  });

  describe('demande écrite (outil d’exploitation)', () => {
    it('confirmation par l’adresse du compte, casse et espaces indifférents : supprimé', async () => {
      const stubs = buildStubs();
      stubs.billing.plan.mockResolvedValue({
        stripe: [{ id: 's1', externalSubscriptionId: 'sub_1' }],
        storeSubscriptionStillActive: false,
      });
      // Le compte rendu dit ce qui a été RÉELLEMENT résilié.
      stubs.billing.stop.mockResolvedValue(['s1']);
      const service = buildService(stubs);

      await expect(
        service.deleteOnWrittenRequest('user-1', '  Lea@Exemple.fr ', false, 'cli-1'),
      ).resolves.toEqual({
        status: 'deleted',
        stripeSubscriptions: 1,
        storeSubscriptionStillActive: false,
      });
      expect(stubs.users.deleteAccount).toHaveBeenCalled();
      expect(stubs.audit.record).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'account.deleted_by_operator', requestId: 'cli-1' }),
      );
    });

    it('à blanc : dit ce qui serait fait, ne touche à rien', async () => {
      const stubs = buildStubs();
      stubs.billing.plan.mockResolvedValue({ stripe: [], storeSubscriptionStillActive: true });
      const service = buildService(stubs);

      await expect(
        service.deleteOnWrittenRequest('user-1', 'lea@exemple.fr', true, 'cli-1'),
      ).resolves.toEqual({
        status: 'planned',
        stripeSubscriptions: 0,
        storeSubscriptionStillActive: true,
      });
      expect(stubs.billing.stop).not.toHaveBeenCalled();
      expect(stubs.users.deleteAccount).not.toHaveBeenCalled();
      expect(stubs.audit.record).not.toHaveBeenCalled();
    });

    it('la confirmation ne correspond pas : refus, rien n’est supprimé', async () => {
      const stubs = buildStubs();
      const service = buildService(stubs);

      const refus = await service.deleteOnWrittenRequest('user-1', 'autre@exemple.fr', false, 'c');

      expect(refus.status).toBe('refused');
      expect(stubs.billing.stop).not.toHaveBeenCalled();
      expect(stubs.users.deleteAccount).not.toHaveBeenCalled();
    });

    it('compte introuvable ou déjà supprimé : refus', async () => {
      const stubs = buildStubs();
      stubs.users.findActiveById.mockResolvedValue(null);
      const service = buildService(stubs);

      const refus = await service.deleteOnWrittenRequest('user-1', 'lea@exemple.fr', false, 'c');

      expect(refus.status).toBe('refused');
      expect(refus.status === 'refused' ? refus.reason : '').toContain('--compte');
      expect(stubs.users.deleteAccount).not.toHaveBeenCalled();
    });
  });
});
