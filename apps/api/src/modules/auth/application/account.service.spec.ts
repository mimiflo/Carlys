import { UnauthorizedException } from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { type AuditService } from '../../audit/audit.service';
import { type UsersRepository } from '../../users/infrastructure/users.repository';
import { type SessionsRepository } from '../infrastructure/sessions.repository';
import { AccountService } from './account.service';
import { type PasswordService } from './password.service';

interface Stubs {
  users: { findPasswordHash: jest.Mock; deleteAccount: jest.Mock };
  sessions: { deleteAllSessions: jest.Mock };
  passwords: { verify: jest.Mock };
  audit: { record: jest.Mock };
}

function buildStubs(): Stubs {
  return {
    users: {
      findPasswordHash: jest.fn().mockResolvedValue('$argon2id$reel'),
      deleteAccount: jest.fn().mockResolvedValue(undefined),
    },
    sessions: { deleteAllSessions: jest.fn().mockResolvedValue(undefined) },
    passwords: { verify: jest.fn().mockResolvedValue(true) },
    audit: { record: jest.fn() },
  };
}

function buildService(stubs: Stubs): AccountService {
  return new AccountService(
    stubs.users as unknown as UsersRepository,
    stubs.sessions as unknown as SessionsRepository,
    stubs.passwords as unknown as PasswordService,
    stubs.audit as unknown as AuditService,
  );
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

  it('sans crédential connue : même refus (jamais de suppression sans preuve)', async () => {
    const stubs = buildStubs();
    stubs.users.findPasswordHash.mockResolvedValue(null);
    const service = buildService(stubs);

    await expect(service.deleteAccount('user-1', 'x', client)).rejects.toThrow(
      UnauthorizedException,
    );
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
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'account.deleted', userId: 'user-1' }),
    );
  });
});
