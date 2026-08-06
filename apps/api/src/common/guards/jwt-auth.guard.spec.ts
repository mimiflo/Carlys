import { type ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { type Reflector } from '@nestjs/core';
import { type JwtService } from '@nestjs/jwt';
import { type AppConfigService } from '../../config/app-config.service';
import { type PrismaService } from '../../database/prisma/prisma.service';
import { type AuthenticatedRequest } from '../types/authenticated-request';
import { JwtAuthGuard } from './jwt-auth.guard';

function contextFor(request: Partial<AuthenticatedRequest>): ExecutionContext {
  return {
    getHandler: () => function handler() {},
    getClass: () => class Controller {},
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

interface GuardStubs {
  reflector: { getAllAndOverride: jest.Mock };
  jwt: { verifyAsync: jest.Mock };
  findSession: jest.Mock;
}

function buildGuard(stubs: GuardStubs): JwtAuthGuard {
  const config = {
    jwtAccessSecret: 'secret-de-test-uniquement-32-caracteres-mini',
    jwtIssuer: 'carlys-api',
    jwtAudience: 'carlys-mobile',
  } as unknown as AppConfigService;
  const prisma = {
    userSession: { findUnique: stubs.findSession },
  } as unknown as PrismaService;

  return new JwtAuthGuard(
    stubs.reflector as unknown as Reflector,
    stubs.jwt as unknown as JwtService,
    config,
    prisma,
  );
}

function buildStubs(): GuardStubs {
  return {
    reflector: { getAllAndOverride: jest.fn().mockReturnValue(false) },
    jwt: {
      verifyAsync: jest.fn().mockResolvedValue({ sub: 'user-1', sid: 'session-1' }),
    },
    findSession: jest.fn().mockResolvedValue({
      userId: 'user-1',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    }),
  };
}

describe('JwtAuthGuard', () => {
  it('laisse passer les routes @Public sans lire le jeton', async () => {
    const stubs = buildStubs();
    stubs.reflector.getAllAndOverride.mockReturnValue(true);
    const guard = buildGuard(stubs);

    await expect(guard.canActivate(contextFor({ headers: {} }))).resolves.toBe(true);
    expect(stubs.jwt.verifyAsync).not.toHaveBeenCalled();
  });

  it('refuse sans en-tête Authorization Bearer', async () => {
    const guard = buildGuard(buildStubs());

    await expect(guard.canActivate(contextFor({ headers: {} }))).rejects.toThrow(
      UnauthorizedException,
    );
    await expect(
      guard.canActivate(contextFor({ headers: { authorization: 'Basic abc' } })),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('refuse un JWT invalide sans détailler la cause', async () => {
    const stubs = buildStubs();
    stubs.jwt.verifyAsync.mockRejectedValue(new Error('jwt expired'));
    const guard = buildGuard(stubs);

    await expect(
      guard.canActivate(contextFor({ headers: { authorization: 'Bearer jeton' } })),
    ).rejects.toThrow('Session expirée ou invalide.');
  });

  it('refuse un JWT valide dont la session est révoquée', async () => {
    const stubs = buildStubs();
    stubs.findSession.mockResolvedValue({
      userId: 'user-1',
      revokedAt: new Date(),
      expiresAt: new Date(Date.now() + 60_000),
    });
    const guard = buildGuard(stubs);

    await expect(
      guard.canActivate(contextFor({ headers: { authorization: 'Bearer jeton' } })),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('refuse une session expirée ou introuvable, ou un sub incohérent', async () => {
    const stubs = buildStubs();
    const guard = buildGuard(stubs);

    stubs.findSession.mockResolvedValue(null);
    await expect(
      guard.canActivate(contextFor({ headers: { authorization: 'Bearer jeton' } })),
    ).rejects.toThrow(UnauthorizedException);

    stubs.findSession.mockResolvedValue({
      userId: 'autre-utilisateur',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });
    await expect(
      guard.canActivate(contextFor({ headers: { authorization: 'Bearer jeton' } })),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('nominal : attache le principal à la requête', async () => {
    const stubs = buildStubs();
    const guard = buildGuard(stubs);
    const request: Partial<AuthenticatedRequest> = {
      headers: { authorization: 'Bearer jeton' },
    };

    await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    expect(request.authUser).toEqual({ userId: 'user-1', sessionId: 'session-1' });
  });
});
