import { ConflictException, NotFoundException } from '@nestjs/common';
import { UserStatus } from '@prisma/client';
import { type AuditService } from '../../audit/audit.service';
import { type AdminRepository } from '../infrastructure/admin.repository';
import { AdminUsersService } from './admin-users.service';

const ACTOR = { adminUserId: 'admin-1', requestId: 'req-1' };

interface Stubs {
  listUsers: jest.Mock;
  findUserById: jest.Mock;
  userActivity: jest.Mock;
  setUserStatus: jest.Mock;
  revokeUserSessions: jest.Mock;
  upsertManualEntitlement: jest.Mock;
}

function userRow(overrides: Record<string, unknown> = {}): unknown {
  return {
    id: 'user-1',
    email: 'membre@carlys.test',
    status: UserStatus.ACTIVE,
    emailVerifiedAt: new Date(),
    createdAt: new Date('2026-08-01T10:00:00Z'),
    updatedAt: new Date(),
    deletedAt: null,
    profile: { userId: 'user-1', displayName: 'Membre' },
    entitlements: [],
    ...overrides,
  };
}

function buildStubs(): Stubs {
  return {
    listUsers: jest.fn().mockResolvedValue([]),
    findUserById: jest.fn().mockResolvedValue(userRow()),
    userActivity: jest.fn().mockResolvedValue({ sessionsCount: 2, completedCount: 5 }),
    setUserStatus: jest.fn().mockResolvedValue(undefined),
    revokeUserSessions: jest.fn().mockResolvedValue(2),
    upsertManualEntitlement: jest.fn().mockResolvedValue(undefined),
  };
}

const auditStub = { record: jest.fn() };

function buildService(stubs: Stubs): AdminUsersService {
  return new AdminUsersService(
    stubs as unknown as AdminRepository,
    auditStub as unknown as AuditService,
  );
}

describe('AdminUsersService', () => {
  beforeEach(() => auditStub.record.mockClear());

  it('suspendre un compte révoque TOUTES ses sessions et audite l’action', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.setUserStatus('user-1', 'SUSPENDED', ACTOR);

    expect(stubs.setUserStatus).toHaveBeenCalledWith('user-1', 'SUSPENDED');
    expect(stubs.revokeUserSessions).toHaveBeenCalledWith('user-1', 'admin_suspension');
    expect(auditStub.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'admin.user_suspended',
        actorType: 'ADMIN',
        adminUserId: 'admin-1',
        metadata: { revokedSessions: 2 },
      }),
    );
  });

  it('réactiver ne révoque rien ; statut inchangé = aucune écriture', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.setUserStatus('user-1', 'ACTIVE', ACTOR);

    expect(stubs.setUserStatus).not.toHaveBeenCalled();
    expect(stubs.revokeUserSessions).not.toHaveBeenCalled();
    expect(auditStub.record).not.toHaveBeenCalled();
  });

  it('un compte supprimé n’est pas modifiable (conflit)', async () => {
    const stubs = buildStubs();
    stubs.findUserById.mockResolvedValue(userRow({ status: UserStatus.DELETED }));
    const service = buildService(stubs);

    await expect(service.setUserStatus('user-1', 'ACTIVE', ACTOR)).rejects.toThrow(
      ConflictException,
    );
  });

  it('attribution manuelle : sourceSubscriptionId null + audit', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.setEntitlement(
      'user-1',
      'premium_exercises',
      { isActive: true, expiresAt: null },
      ACTOR,
    );

    expect(stubs.upsertManualEntitlement).toHaveBeenCalledWith('user-1', 'premium_exercises', {
      isActive: true,
      expiresAt: null,
    });
    expect(auditStub.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.entitlement_granted', actorType: 'ADMIN' }),
    );
  });

  it('utilisateur inconnu → 404', async () => {
    const stubs = buildStubs();
    stubs.findUserById.mockResolvedValue(null);
    const service = buildService(stubs);

    await expect(service.userDetail('inconnu')).rejects.toThrow(NotFoundException);
  });

  it('le détail expose l’activité et TOUTES les clés de droits', async () => {
    const stubs = buildStubs();
    stubs.findUserById.mockResolvedValue(
      userRow({
        entitlements: [
          {
            id: 'ent-1',
            userId: 'user-1',
            entitlementKey: 'premium_exercises',
            isActive: true,
            expiresAt: null,
            sourceSubscriptionId: null,
          },
        ],
      }),
    );
    const service = buildService(stubs);

    const detail = await service.userDetail('user-1');

    expect(detail.isPremium).toBe(true);
    expect(detail.sessionsCount).toBe(2);
    expect(detail.completedWorkoutsCount).toBe(5);
    expect(detail.entitlements.length).toBeGreaterThanOrEqual(9);
  });
});
