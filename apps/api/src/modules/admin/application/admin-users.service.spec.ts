import { ConflictException, NotFoundException } from '@nestjs/common';
import { UserStatus } from '@prisma/client';
import { type AuditService } from '../../audit/audit.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { type AdminUsersRepository } from '../infrastructure/admin-users.repository';
import { AdminUsersService } from './admin-users.service';

const ACTOR = { adminUserId: 'admin-1', requestId: 'req-1' };

interface Stubs {
  listUsers: jest.Mock;
  findUserById: jest.Mock;
  userActivity: jest.Mock;
  setUserStatus: jest.Mock;
  revokeUserSessions: jest.Mock;
  upsertManualEntitlement: jest.Mock;
  listSubscriptions: jest.Mock;
  deleteManualEntitlement: jest.Mock;
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
    listSubscriptions: jest.fn().mockResolvedValue([]),
    deleteManualEntitlement: jest.fn().mockResolvedValue(1),
  };
}

const auditStub = { record: jest.fn() };
const entitlementsStub = { resyncFromSubscriptions: jest.fn().mockResolvedValue(undefined) };

function buildService(stubs: Stubs): AdminUsersService {
  return new AdminUsersService(
    stubs as unknown as AdminUsersRepository,
    auditStub as unknown as AuditService,
    entitlementsStub as unknown as EntitlementsService,
  );
}

function entitlementRow(overrides: Record<string, unknown>): unknown {
  return {
    id: 'ent-1',
    userId: 'user-1',
    entitlementKey: 'premium_exercises',
    isActive: true,
    expiresAt: null,
    sourceSubscriptionId: null,
    sourceSubscription: null,
    ...overrides,
  };
}

describe('AdminUsersService', () => {
  beforeEach(() => {
    auditStub.record.mockClear();
    entitlementsStub.resyncFromSubscriptions.mockClear();
  });

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

  it('le détail dit D’OÙ vient chaque droit : abonnement (et fournisseur), octroi, coupure, rien', async () => {
    const stubs = buildStubs();
    stubs.findUserById.mockResolvedValue(
      userRow({
        entitlements: [
          entitlementRow({
            entitlementKey: 'premium_exercises',
            sourceSubscriptionId: 'sub-1',
            sourceSubscription: { provider: 'STRIPE' },
          }),
          entitlementRow({ entitlementKey: 'ai_coaching', isActive: false }),
          entitlementRow({ entitlementKey: 'cloud_backup', isActive: true }),
        ],
      }),
    );
    stubs.listSubscriptions.mockResolvedValue([
      { provider: 'STRIPE', status: 'ACTIVE', currentPeriodEnd: null, cancelAtPeriodEnd: false },
    ]);
    const service = buildService(stubs);

    const detail = await service.userDetail('user-1');
    const byKey = new Map(detail.entitlements.map((entitlement) => [entitlement.key, entitlement]));

    expect(byKey.get('premium_exercises')).toMatchObject({
      source: 'SUBSCRIPTION',
      provider: 'STRIPE',
    });
    expect(byKey.get('ai_coaching')).toMatchObject({ source: 'MANUAL_REVOCATION' });
    expect(byKey.get('ai_coaching')).not.toHaveProperty('provider');
    expect(byKey.get('cloud_backup')).toMatchObject({ source: 'MANUAL_GRANT' });
    expect(byKey.get('health_sync')).toMatchObject({ source: 'NONE', isActive: false });
    expect(detail.paidSubscription).toEqual({
      provider: 'STRIPE',
      status: 'ACTIVE',
      currentPeriodEnd: null,
      cancelAtPeriodEnd: false,
    });
  });

  it('rendre la main à l’abonnement : la ligne manuelle part, les droits se recalculent, c’est audité', async () => {
    const stubs = buildStubs();
    stubs.findUserById.mockResolvedValue(
      userRow({ entitlements: [entitlementRow({ isActive: false })] }),
    );
    const service = buildService(stubs);

    await service.releaseEntitlement('user-1', 'premium_exercises', ACTOR);

    expect(stubs.deleteManualEntitlement).toHaveBeenCalledWith('user-1', 'premium_exercises');
    expect(entitlementsStub.resyncFromSubscriptions).toHaveBeenCalledWith('user-1');
    expect(stubs.deleteManualEntitlement.mock.invocationCallOrder[0]).toBeLessThan(
      entitlementsStub.resyncFromSubscriptions.mock.invocationCallOrder[0] ?? 0,
    );
    expect(auditStub.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'admin.entitlement_released',
        metadata: { key: 'premium_exercises', previousSource: 'MANUAL_REVOCATION', removed: true },
      }),
    );
  });

  it('une coupure garde sa raison dans l’audit', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.setEntitlement(
      'user-1',
      'premium_exercises',
      { isActive: false, expiresAt: null, reason: 'Fraude au remboursement' },
      ACTOR,
    );

    expect(auditStub.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'admin.entitlement_revoked',
        metadata: { key: 'premium_exercises', expiresAt: null, reason: 'Fraude au remboursement' },
      }),
    );
  });
});
