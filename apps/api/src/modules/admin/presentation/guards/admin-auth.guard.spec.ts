import { type ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { type JwtService } from '@nestjs/jwt';
import { AdminUserStatus } from '@prisma/client';
import { type AppConfigService } from '../../../../config/app-config.service';
import { type AdminRepository } from '../../infrastructure/admin.repository';
import { AdminAuthGuard, type AdminRequest } from './admin-auth.guard';

function contextFor(request: Partial<AdminRequest>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

interface Stubs {
  jwt: { verifyAsync: jest.Mock };
  admins: { findAdminById: jest.Mock };
}

function adminRow(status: AdminUserStatus = AdminUserStatus.ACTIVE): unknown {
  return {
    id: 'admin-1',
    email: 'support@carlys.local',
    status,
    roles: [
      {
        role: {
          slug: 'support',
          permissions: [{ permission: { resource: 'user', action: 'read' } }],
        },
      },
    ],
  };
}

function buildStubs(): Stubs {
  return {
    jwt: { verifyAsync: jest.fn().mockResolvedValue({ sub: 'admin-1', adm: true }) },
    admins: { findAdminById: jest.fn().mockResolvedValue(adminRow()) },
  };
}

function buildGuard(stubs: Stubs): AdminAuthGuard {
  const config = {
    jwtAccessSecret: 'secret-de-test-uniquement-32-caracteres-mini',
    jwtIssuer: 'carlys-api',
  } as unknown as AppConfigService;
  return new AdminAuthGuard(
    stubs.jwt as unknown as JwtService,
    config,
    stubs.admins as unknown as AdminRepository,
  );
}

const bearer = { headers: { authorization: 'Bearer jeton' } };

/**
 * Authentification du back-office : audience dédiée, compte relu en base à
 * CHAQUE requête. La garde échoue FERMÉ : jeton absent, invalide, sans le
 * marqueur admin, compte inconnu ou désactivé, tout est 401.
 */
describe('AdminAuthGuard', () => {
  it('refuse sans en-tête Bearer', async () => {
    const guard = buildGuard(buildStubs());

    await expect(guard.canActivate(contextFor({ headers: {} }))).rejects.toThrow(
      UnauthorizedException,
    );
    await expect(
      guard.canActivate(contextFor({ headers: { authorization: 'Basic abc' } })),
    ).rejects.toThrow(UnauthorizedException);
    await expect(
      guard.canActivate(contextFor({ headers: { authorization: 'Bearer ' } })),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('vérifie le jeton avec l’audience ADMIN, et refuse un jeton invalide sans détailler', async () => {
    const stubs = buildStubs();
    stubs.jwt.verifyAsync.mockRejectedValue(new Error('jwt audience invalid'));
    const guard = buildGuard(stubs);

    await expect(guard.canActivate(contextFor(bearer))).rejects.toThrow(
      'Session administrateur expirée ou invalide.',
    );
    expect(stubs.jwt.verifyAsync).toHaveBeenCalledWith(
      'jeton',
      expect.objectContaining({ audience: 'carlys-admin', issuer: 'carlys-api' }),
    );
  });

  it('refuse un jeton signé mais sans le marqueur admin (un jeton mobile, par exemple)', async () => {
    const stubs = buildStubs();
    stubs.jwt.verifyAsync.mockResolvedValue({ sub: 'user-1' });
    const guard = buildGuard(stubs);

    await expect(guard.canActivate(contextFor(bearer))).rejects.toThrow(UnauthorizedException);
    expect(stubs.admins.findAdminById).not.toHaveBeenCalled();
  });

  it('refuse un compte introuvable', async () => {
    const stubs = buildStubs();
    stubs.admins.findAdminById.mockResolvedValue(null);
    const guard = buildGuard(stubs);

    await expect(guard.canActivate(contextFor(bearer))).rejects.toThrow(UnauthorizedException);
  });

  it('refuse un compte DÉSACTIVÉ même si le jeton est encore valide : désactiver révoque aussitôt', async () => {
    const stubs = buildStubs();
    stubs.admins.findAdminById.mockResolvedValue(adminRow(AdminUserStatus.DISABLED));
    const guard = buildGuard(stubs);

    await expect(guard.canActivate(contextFor(bearer))).rejects.toThrow(UnauthorizedException);
  });

  it('nominal : attache le principal (identité et permissions relues en base)', async () => {
    const stubs = buildStubs();
    const guard = buildGuard(stubs);
    const request: Partial<AdminRequest> = { ...bearer };

    await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    expect(stubs.admins.findAdminById).toHaveBeenCalledWith('admin-1');
    expect(request.adminPrincipal).toEqual({
      adminUserId: 'admin-1',
      email: 'support@carlys.local',
      permissions: ['user:read'],
    });
  });
});
