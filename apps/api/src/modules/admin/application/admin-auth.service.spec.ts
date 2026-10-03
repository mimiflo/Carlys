import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  UnauthorizedException,
} from '@nestjs/common';
import { type JwtService } from '@nestjs/jwt';
import { AdminUserStatus } from '@prisma/client';
import { type AuditService } from '../../audit/audit.service';
import { type LockoutService } from '../../auth/application/lockout.service';
import { type PasswordService } from '../../auth/application/password.service';
import { type AppConfigService } from '../../../config/app-config.service';
import { type AdminRepository } from '../infrastructure/admin.repository';
import { AdminAuthService } from './admin-auth.service';
import { type AdminTotpService } from './admin-totp.service';

interface Stubs {
  admins: {
    findAdminByEmail: jest.Mock;
    findAdminById: jest.Mock;
    markLogin: jest.Mock;
    reserveTotpAttempt: jest.Mock;
  };
  passwords: { verify: jest.Mock; hash: jest.Mock };
  jwt: { signAsync: jest.Mock };
  audit: { record: jest.Mock };
  lockout: { reserveAttempt: jest.Mock; reset: jest.Mock };
  totp: { challengeFor: jest.Mock; adminIdOf: jest.Mock; consumeCode: jest.Mock };
}

function adminRow(overrides: Record<string, unknown> = {}): unknown {
  return {
    id: 'admin-1',
    email: 'admin@carlys.local',
    passwordHash: 'hash',
    displayName: 'Admin',
    status: AdminUserStatus.ACTIVE,
    lastLoginAt: null,
    totpSecret: 'v1.secret-chiffre',
    totpEnabledAt: new Date('2026-10-01'),
    totpLastStep: null,
    totpFailedAttempts: 0,
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
      reserveTotpAttempt: jest.fn().mockResolvedValue(true),
    },
    passwords: {
      verify: jest.fn().mockResolvedValue(true),
      hash: jest.fn().mockResolvedValue('hash-factice'),
    },
    jwt: { signAsync: jest.fn().mockResolvedValue('jeton-admin') },
    audit: { record: jest.fn() },
    lockout: {
      reserveAttempt: jest.fn().mockResolvedValue({ locked: false }),
      reset: jest.fn().mockResolvedValue(undefined),
    },
    totp: {
      challengeFor: jest.fn().mockResolvedValue({ challengeToken: 'defi' }),
      adminIdOf: jest.fn().mockResolvedValue('admin-1'),
      consumeCode: jest.fn().mockResolvedValue(true),
    },
  };
}

function buildService(stubs: Stubs): AdminAuthService {
  const config = {
    jwtAccessSecret: 'secret-test-32-caracteres-minimum!!',
    jwtIssuer: 'carlys-api',
    logFingerprintKey: Buffer.from('cle-de-test'),
  };
  return new AdminAuthService(
    stubs.admins as unknown as AdminRepository,
    stubs.passwords as unknown as PasswordService,
    stubs.jwt as unknown as JwtService,
    config as unknown as AppConfigService,
    stubs.audit as unknown as AuditService,
    stubs.lockout as unknown as LockoutService,
    stubs.totp as unknown as AdminTotpService,
  );
}

const CLIENT = { ipAddress: '127.0.0.1' };

describe('AdminAuthService', () => {
  it('mot de passe juste : AUCUNE session, la seconde étape (code), compteur remis à zéro', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    const result = await service.login(
      { email: 'Admin@Carlys.local', password: 'MotDePasseSolide42' },
      CLIENT,
    );

    expect(result).toEqual({ challengeToken: 'defi' });
    expect(stubs.jwt.signAsync).not.toHaveBeenCalled();
    expect(stubs.admins.markLogin).not.toHaveBeenCalled();
    expect(stubs.admins.findAdminByEmail).toHaveBeenCalledWith('admin@carlys.local');
    // Compteur PROPRE au back-office : jamais celui d'un compte mobile de même adresse.
    expect(stubs.lockout.reserveAttempt).toHaveBeenCalledWith('admin:admin@carlys.local');
    expect(stubs.lockout.reset).toHaveBeenCalledWith('admin:admin@carlys.local');
  });

  it('code juste : session à audience dédiée, marquée mfa, rôles et permissions', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    const result = await service.verifySecondFactor(
      { challengeToken: 'defi', code: '123456' },
      CLIENT,
    );

    expect(result.accessToken).toBe('jeton-admin');
    expect(result.admin.roles).toEqual(['support']);
    expect(result.admin.permissions).toEqual(['audit:read', 'user:read']);
    expect(stubs.jwt.signAsync).toHaveBeenCalledWith(
      { adm: true, mfa: true },
      expect.objectContaining({ audience: 'carlys-admin', subject: 'admin-1' }),
    );
    expect(stubs.lockout.reserveAttempt).toHaveBeenCalledWith('admin-totp:admin-1');
    expect(stubs.admins.markLogin).toHaveBeenCalledWith('admin-1');
  });

  it('code faux ou déjà servi : 401, audité, aucune session', async () => {
    const stubs = buildStubs();
    stubs.totp.consumeCode.mockResolvedValue(false);
    const service = buildService(stubs);

    await expect(
      service.verifySecondFactor({ challengeToken: 'defi', code: '000000' }, CLIENT),
    ).rejects.toThrow(UnauthorizedException);
    expect(stubs.jwt.signAsync).not.toHaveBeenCalled();
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.totp_failed', adminUserId: 'admin-1' }),
    );
  });

  it('trop d’essais de code : 429 avant même de lire le compte', async () => {
    const stubs = buildStubs();
    stubs.lockout.reserveAttempt.mockResolvedValue({ locked: true, retryAfterSeconds: 600 });
    const service = buildService(stubs);

    await expect(
      service.verifySecondFactor({ challengeToken: 'defi', code: '123456' }, CLIENT),
    ).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });
    expect(stubs.totp.consumeCode).not.toHaveBeenCalled();
  });

  it('20 codes faux d’affilée : 2FA gelée en base (403), plus aucun code vérifié', async () => {
    const stubs = buildStubs();
    stubs.admins.reserveTotpAttempt.mockResolvedValue(false);
    const service = buildService(stubs);

    await expect(
      service.verifySecondFactor({ challengeToken: 'defi', code: '123456' }, CLIENT),
    ).rejects.toThrow(ForbiddenException);
    expect(stubs.totp.consumeCode).not.toHaveBeenCalled();
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.totp_frozen', adminUserId: 'admin-1' }),
    );
  });

  it('aucun secret émis : refus audité, pointe vers l’opérateur', async () => {
    const stubs = buildStubs();
    stubs.admins.findAdminByEmail.mockResolvedValue(adminRow({ totpSecret: null }));
    stubs.totp.challengeFor.mockRejectedValue(new ForbiddenException());
    const service = buildService(stubs);

    await expect(
      service.login({ email: 'admin@carlys.local', password: 'MotDePasseSolide42' }, CLIENT),
    ).rejects.toThrow(ForbiddenException);
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.totp_not_issued', adminUserId: 'admin-1' }),
    );
  });

  it('premier code juste : l’enrôlement est audité', async () => {
    const stubs = buildStubs();
    stubs.admins.findAdminById.mockResolvedValue(adminRow({ totpEnabledAt: null }));
    const service = buildService(stubs);

    await service.verifySecondFactor({ challengeToken: 'defi', code: '123456' }, CLIENT);

    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.totp_enrolled', adminUserId: 'admin-1' }),
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
    // L'audit survit aux comptes et se lit au back-office : l'adresse saisie
    // n'y entre qu'en empreinte à clé, jamais en clair.
    expect(JSON.stringify(stubs.audit.record.mock.calls)).not.toContain('inconnu@carlys.local');
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        metadata: { emailHash: expect.stringMatching(/^[0-9a-f]{12}$/) as unknown },
      }),
    );
    // Un compte inconnu compte AUSSI comme essai : le compteur ne trahit pas son absence.
    expect(stubs.lockout.reserveAttempt).toHaveBeenCalledWith('admin:inconnu@carlys.local');
    expect(stubs.lockout.reset).not.toHaveBeenCalled();
  });

  it('compte désactivé : refusé même avec le bon mot de passe', async () => {
    const stubs = buildStubs();
    stubs.admins.findAdminByEmail.mockResolvedValue(adminRow({ status: AdminUserStatus.DISABLED }));
    const service = buildService(stubs);

    await expect(
      service.login({ email: 'admin@carlys.local', password: 'MotDePasseSolide42' }, CLIENT),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('mauvais mot de passe : refus + audit, essai réservé AVANT la vérification', async () => {
    const stubs = buildStubs();
    stubs.passwords.verify.mockResolvedValue(false);
    const service = buildService(stubs);

    await expect(
      service.login({ email: 'admin@carlys.local', password: 'mauvais-mdp!' }, CLIENT),
    ).rejects.toThrow(UnauthorizedException);
    expect(stubs.admins.markLogin).not.toHaveBeenCalled();
    // L'essai a été RÉSERVÉ avant la vérification ; l'échec ne remet rien à zéro.
    expect(stubs.lockout.reserveAttempt).toHaveBeenCalledWith('admin:admin@carlys.local');
    expect(stubs.lockout.reserveAttempt.mock.invocationCallOrder[0]).toBeLessThan(
      stubs.passwords.verify.mock.invocationCallOrder[0] ?? 0,
    );
    expect(stubs.lockout.reset).not.toHaveBeenCalled();
  });

  it('au-delà du seuil : 429 sans lire le compte ni révéler son état, même avec le bon mot de passe', async () => {
    const stubs = buildStubs();
    stubs.lockout.reserveAttempt.mockResolvedValue({ locked: true, retryAfterSeconds: 300 });
    const service = buildService(stubs);

    const attempt = service.login(
      { email: 'admin@carlys.local', password: 'MotDePasseSolide42' },
      CLIENT,
    );

    await expect(attempt).rejects.toThrow(HttpException);
    await expect(attempt).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });
    // Le refus précède toute lecture : ni la base ni le hash ne sont sollicités.
    expect(stubs.admins.findAdminByEmail).not.toHaveBeenCalled();
    expect(stubs.passwords.verify).not.toHaveBeenCalled();
    expect(stubs.jwt.signAsync).not.toHaveBeenCalled();
    expect(stubs.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'admin.login_blocked_lockout', actorType: 'ADMIN' }),
    );
    // Le message ne dit ni que le compte existe, ni qu'il est verrouillé.
    await expect(attempt).rejects.toThrow(/Trop de tentatives/);
    await expect(attempt).rejects.not.toThrow(/verrouill|compte/i);
  });
});
