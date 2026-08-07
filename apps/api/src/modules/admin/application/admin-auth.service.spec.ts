import { UnauthorizedException } from '@nestjs/common';
import { type JwtService } from '@nestjs/jwt';
import { AdminUserStatus } from '@prisma/client';
import { type AuditService } from '../../audit/audit.service';
import { type PasswordService } from '../../auth/application/password.service';
import { type AppConfigService } from '../../../config/app-config.service';
import { type AdminRepository } from '../infrastructure/admin.repository';
import { AdminAuthService } from './admin-auth.service';

interface Stubs {
  admins: { findAdminByEmail: jest.Mock; findAdminById: jest.Mock; markLogin: jest.Mock };
  passwords: { verify: jest.Mock; hash: jest.Mock };
  jwt: { signAsync: jest.Mock };
  audit: { record: jest.Mock };
}

function adminRow(overrides: Record<string, unknown> = {}): unknown {
  return {
    id: 'admin-1',
    email: 'admin@carlys.local',
    passwordHash: 'hash',
    displayName: 'Admin',
    status: AdminUserStatus.ACTIVE,
    lastLoginAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    roles: [
      {
        adminUserId: 'admin-1',
        roleId: 'role-1',
        role: {
          id: 'role-1',
          slug: 'support',
          name: 'Support',
          description: null,
          permissions: [
            {
              roleId: 'role-1',
              permissionId: 'p-1',
              permission: { id: 'p-1', resource: 'user', action: 'read' },
            },
            {
              roleId: 'role-1',
              permissionId: 'p-2',
              permission: { id: 'p-2', resource: 'audit', action: 'read' },
            },
          ],
        },
      },
    ],
    ...overrides,
  };
}

function buildStubs(): Stubs {
  return {
    admins: {
      findAdminByEmail: jest.fn().mockResolvedValue(adminRow()),
      findAdminById: jest.fn().mockResolvedValue(adminRow()),
      markLogin: jest.fn().mockResolvedValue(undefined),
    },
    passwords: {
      verify: jest.fn().mockResolvedValue(true),
      hash: jest.fn().mockResolvedValue('hash-factice'),
    },
    jwt: { signAsync: jest.fn().mockResolvedValue('jeton-admin') },
    audit: { record: jest.fn() },
  };
}

function buildService(stubs: Stubs): AdminAuthService {
  const config = {
    jwtAccessSecret: 'secret-test-32-caracteres-minimum!!',
    jwtIssuer: 'carlys-api',
  };
  return new AdminAuthService(
    stubs.admins as unknown as AdminRepository,
    stubs.passwords as unknown as PasswordService,
    stubs.jwt as unknown as JwtService,
    config as unknown as AppConfigService,
    stubs.audit as unknown as AuditService,
  );
}

const CLIENT = { ipAddress: '127.0.0.1' };

describe('AdminAuthService', () => {
  it('connexion réussie : jeton à audience dédiée, rôles et permissions', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    const result = await service.login(
      { email: 'Admin@Carlys.local', password: 'MotDePasseSolide42' },
      CLIENT,
    );

    expect(result.accessToken).toBe('jeton-admin');
    expect(result.admin.roles).toEqual(['support']);
    expect(result.admin.permissions).toEqual(['audit:read', 'user:read']);
    expect(stubs.admins.findAdminByEmail).toHaveBeenCalledWith('admin@carlys.local');
    expect(stubs.jwt.signAsync).toHaveBeenCalledWith(
      { adm: true },
      expect.objectContaining({ audience: 'carlys-admin', subject: 'admin-1' }),
    );
  });

  it('compte inconnu : hachage factice quand même (anti-énumération), message uniforme', async () => {
    const stubs = buildStubs();
    stubs.admins.findAdminByEmail.mockResolvedValue(null);
    const service = buildService(stubs);

    await expect(
      service.login({ email: 'inconnu@carlys.local', password: 'x'.repeat(12) }, CLIENT),
    ).rejects.toThrow(UnauthorizedException);
    expect(stubs.passwords.hash).toHaveBeenCalled();
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.login_failed', actorType: 'ADMIN' }),
    );
  });

  it('compte désactivé : refusé même avec le bon mot de passe', async () => {
    const stubs = buildStubs();
    stubs.admins.findAdminByEmail.mockResolvedValue(adminRow({ status: AdminUserStatus.DISABLED }));
    const service = buildService(stubs);

    await expect(
      service.login({ email: 'admin@carlys.local', password: 'MotDePasseSolide42' }, CLIENT),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('mauvais mot de passe : refus + audit', async () => {
    const stubs = buildStubs();
    stubs.passwords.verify.mockResolvedValue(false);
    const service = buildService(stubs);

    await expect(
      service.login({ email: 'admin@carlys.local', password: 'mauvais-mdp!' }, CLIENT),
    ).rejects.toThrow(UnauthorizedException);
    expect(stubs.admins.markLogin).not.toHaveBeenCalled();
  });
});
