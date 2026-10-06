import { type ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { type Reflector } from '@nestjs/core';
import { type JwtService } from '@nestjs/jwt';
import { type AppConfigService } from '../../config/app-config.service';
import { type PrismaService } from '../../database/prisma/prisma.service';
import { type SessionCache } from '../../infrastructure/cache/session-cache';
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
  /** Par défaut : Redis indisponible (`null`), la base décide. */
  cache: { lookup: jest.Mock; remember: jest.Mock };
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
    stubs.cache as unknown as SessionCache,
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
    cache: { lookup: jest.fn().mockResolvedValue(null), remember: jest.fn() },
  };
}

const bearer = () => contextFor({ headers: { authorization: 'Bearer jeton' } });

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

  describe('cache des sessions', () => {
    it('session valide en cache : la base n’est pas lue', async () => {
      const stubs = buildStubs();
      stubs.cache.lookup.mockResolvedValue({ expiresAt: Date.now() + 60_000, generation: 'g' });

      await expect(buildGuard(stubs).canActivate(bearer())).resolves.toBe(true);
      expect(stubs.cache.lookup).toHaveBeenCalledWith('user-1', 'session-1');
      expect(stubs.findSession).not.toHaveBeenCalled();
    });

    it('absente du cache : la base décide, puis la session est retenue avec la génération lue', async () => {
      const stubs = buildStubs();
      stubs.cache.lookup.mockResolvedValue({ expiresAt: null, generation: 'g-7' });

      await expect(buildGuard(stubs).canActivate(bearer())).resolves.toBe(true);
      expect(stubs.findSession).toHaveBeenCalled();
      expect(stubs.cache.remember).toHaveBeenCalledWith(
        'user-1',
        'session-1',
        expect.any(Date),
        'g-7',
      );
    });

    it('échéance en cache dépassée : la base décide (et refuse une session révoquée)', async () => {
      const stubs = buildStubs();
      stubs.cache.lookup.mockResolvedValue({ expiresAt: Date.now() - 1, generation: '' });
      stubs.findSession.mockResolvedValue({
        userId: 'user-1',
        revokedAt: new Date(),
        expiresAt: new Date(Date.now() + 60_000),
      });

      await expect(buildGuard(stubs).canActivate(bearer())).rejects.toThrow(UnauthorizedException);
      expect(stubs.cache.remember).not.toHaveBeenCalled();
    });

    it('Redis indisponible : la base décide, rien n’est écrit', async () => {
      const stubs = buildStubs();

      await expect(buildGuard(stubs).canActivate(bearer())).resolves.toBe(true);
      expect(stubs.findSession).toHaveBeenCalled();
      expect(stubs.cache.remember).not.toHaveBeenCalled();
    });
  });
});
