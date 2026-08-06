import { ConflictException, HttpException, UnauthorizedException } from '@nestjs/common';
import { RefreshTokenStatus, UserStatus } from '@prisma/client';
import { type AppConfigService } from '../../../config/app-config.service';
import { type EmailService } from '../../../infrastructure/email/email.service';
import { type AuditService } from '../../audit/audit.service';
import { type UsersRepository } from '../../users/infrastructure/users.repository';
import {
  type RefreshTokenWithSession,
  type SessionsRepository,
} from '../infrastructure/sessions.repository';
import { type VerificationRepository } from '../infrastructure/verification.repository';
import { AuthService } from './auth.service';
import { type LockoutService } from './lockout.service';
import { type PasswordService } from './password.service';
import { type SessionsService } from './sessions.service';
import { TokenService } from './token.service';

const GENERIC_MESSAGE = 'E-mail ou mot de passe incorrect.';

interface Stubs {
  users: jest.Mocked<
    Pick<
      UsersRepository,
      | 'findActiveByEmail'
      | 'findActiveById'
      | 'emailExists'
      | 'findPasswordHash'
      | 'updatePasswordHash'
    >
  >;
  sessions: jest.Mocked<
    Pick<
      SessionsRepository,
      'findRefreshTokenByHash' | 'rotateRefreshToken' | 'revokeSession' | 'revokeAllSessions'
    >
  >;
  verifications: jest.Mocked<
    Pick<VerificationRepository, 'createPasswordReset' | 'findPasswordReset'>
  >;
  sessionsService: jest.Mocked<Pick<SessionsService, 'open'>>;
  passwords: jest.Mocked<Pick<PasswordService, 'hash' | 'verify'>>;
  tokens: {
    generateRefreshToken: jest.Mock;
    generateOpaqueToken: jest.Mock;
    signAccessToken: jest.Mock;
  };
  lockout: jest.Mocked<Pick<LockoutService, 'status' | 'recordFailure' | 'reset'>>;
  email: jest.Mocked<Pick<EmailService, 'sendEmailVerification' | 'sendPasswordReset'>>;
  audit: jest.Mocked<Pick<AuditService, 'record'>>;
}

function buildStubs(): Stubs {
  return {
    users: {
      findActiveByEmail: jest.fn(),
      findActiveById: jest.fn(),
      emailExists: jest.fn().mockResolvedValue(null),
      findPasswordHash: jest.fn(),
      updatePasswordHash: jest.fn().mockResolvedValue(undefined),
    },
    sessions: {
      findRefreshTokenByHash: jest.fn(),
      rotateRefreshToken: jest.fn().mockResolvedValue(true),
      revokeSession: jest.fn().mockResolvedValue(undefined),
      revokeAllSessions: jest.fn().mockResolvedValue(undefined),
    },
    verifications: {
      createPasswordReset: jest.fn().mockResolvedValue(undefined),
      findPasswordReset: jest.fn(),
    },
    sessionsService: {
      open: jest.fn().mockResolvedValue({
        accessToken: 'jwt',
        accessTokenExpiresIn: 900,
        refreshToken: 'refresh',
        refreshTokenExpiresAt: new Date(Date.now() + 1_000_000).toISOString(),
      }),
    },
    passwords: {
      hash: jest.fn().mockResolvedValue('$argon2id$factice'),
      verify: jest.fn().mockResolvedValue(false),
    },
    tokens: {
      generateRefreshToken: jest.fn().mockReturnValue({
        token: 'nouveau-jeton',
        tokenHash: 'hash-du-nouveau-jeton',
        expiresAt: new Date(Date.now() + 1_000_000),
      }),
      generateOpaqueToken: jest.fn().mockReturnValue({
        token: 'jeton-opaque',
        tokenHash: 'hash-opaque',
        expiresAt: new Date(Date.now() + 1_000_000),
      }),
      signAccessToken: jest.fn().mockResolvedValue('jwt'),
    },
    lockout: {
      status: jest.fn().mockResolvedValue({ locked: false }),
      recordFailure: jest.fn().mockResolvedValue(undefined),
      reset: jest.fn().mockResolvedValue(undefined),
    },
    email: {
      sendEmailVerification: jest.fn(),
      sendPasswordReset: jest.fn(),
    },
    audit: { record: jest.fn() },
  };
}

function buildService(stubs: Stubs): AuthService {
  const config = {
    jwtAccessTtlSeconds: 900,
    passwordResetTtlMinutes: 60,
    emailVerificationTtlHours: 24,
  } as unknown as AppConfigService;

  return new AuthService(
    stubs.users as unknown as UsersRepository,
    stubs.sessions as unknown as SessionsRepository,
    stubs.verifications as unknown as VerificationRepository,
    stubs.sessionsService as unknown as SessionsService,
    stubs.passwords as unknown as PasswordService,
    stubs.tokens as unknown as TokenService,
    stubs.lockout as unknown as LockoutService,
    stubs.email as unknown as EmailService,
    stubs.audit as unknown as AuditService,
    config,
  );
}

function storedToken(
  overrides: Partial<RefreshTokenWithSession> = {},
  sessionOverrides: Partial<RefreshTokenWithSession['session']> = {},
): RefreshTokenWithSession {
  const future = new Date(Date.now() + 1_000_000);
  return {
    id: 'token-1',
    sessionId: 'session-1',
    tokenHash: TokenService.hashToken('jeton-client'),
    status: RefreshTokenStatus.ACTIVE,
    createdAt: new Date(),
    expiresAt: future,
    rotatedAt: null,
    session: {
      id: 'session-1',
      userId: 'user-1',
      deviceName: null,
      devicePlatform: null,
      ipAddress: null,
      userAgent: null,
      createdAt: new Date(),
      lastUsedAt: new Date(),
      expiresAt: future,
      revokedAt: null,
      revokedReason: null,
      user: {
        id: 'user-1',
        email: 'a@b.fr',
        status: UserStatus.ACTIVE,
        emailVerifiedAt: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        deletedAt: null,
      },
      ...sessionOverrides,
    },
    ...overrides,
  };
}

const client = { ipAddress: '127.0.0.1', userAgent: 'jest' };

describe('AuthService', () => {
  describe('login', () => {
    it('refuse avec 429 quand le compte est verrouillé, sans toucher à la base', async () => {
      const stubs = buildStubs();
      stubs.lockout.status.mockResolvedValue({ locked: true, retryAfterSeconds: 300 });
      const service = buildService(stubs);

      await expect(
        service.login({ email: 'A@B.fr', password: 'x'.repeat(10) }, client),
      ).rejects.toThrow(HttpException);
      expect(stubs.users.findActiveByEmail).not.toHaveBeenCalled();
      expect(stubs.audit.record).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'auth.login_blocked_lockout' }),
      );
    });

    it('compte inconnu : hachage factice (temps constant), échec compté, message générique', async () => {
      const stubs = buildStubs();
      stubs.users.findActiveByEmail.mockResolvedValue(null);
      const service = buildService(stubs);

      await expect(
        service.login({ email: 'Inconnu@B.fr', password: 'x'.repeat(10) }, client),
      ).rejects.toThrow(GENERIC_MESSAGE);
      expect(stubs.passwords.hash).toHaveBeenCalled();
      expect(stubs.lockout.recordFailure).toHaveBeenCalledWith('inconnu@b.fr');
    });

    it('mot de passe erroné : même message générique que compte inconnu', async () => {
      const stubs = buildStubs();
      stubs.users.findActiveByEmail.mockResolvedValue({
        id: 'user-1',
        email: 'a@b.fr',
        status: UserStatus.ACTIVE,
        profile: null,
      } as never);
      stubs.users.findPasswordHash.mockResolvedValue('$argon2id$reel');
      stubs.passwords.verify.mockResolvedValue(false);
      const service = buildService(stubs);

      await expect(
        service.login({ email: 'a@b.fr', password: 'mauvais-mdp' }, client),
      ).rejects.toThrow(GENERIC_MESSAGE);
      expect(stubs.lockout.recordFailure).toHaveBeenCalledWith('a@b.fr');
      expect(stubs.sessionsService.open).not.toHaveBeenCalled();
    });
  });

  describe('register', () => {
    it('refuse un e-mail déjà pris (normalisé en minuscules)', async () => {
      const stubs = buildStubs();
      stubs.users.emailExists.mockResolvedValue({ id: 'user-1' } as never);
      const service = buildService(stubs);

      await expect(
        service.register({ email: 'A@B.fr', password: 'x'.repeat(10), displayName: 'A' }, client),
      ).rejects.toThrow(ConflictException);
      expect(stubs.users.emailExists).toHaveBeenCalledWith('a@b.fr');
    });
  });

  describe('refresh', () => {
    it('jeton inconnu → 401 sans autre action', async () => {
      const stubs = buildStubs();
      stubs.sessions.findRefreshTokenByHash.mockResolvedValue(null);
      const service = buildService(stubs);

      await expect(service.refresh('inconnu', client)).rejects.toThrow(UnauthorizedException);
      expect(stubs.sessions.revokeSession).not.toHaveBeenCalled();
    });

    it('jeton ROTATED rejoué → révocation de la session + audit de réutilisation', async () => {
      const stubs = buildStubs();
      stubs.sessions.findRefreshTokenByHash.mockResolvedValue(
        storedToken({ status: RefreshTokenStatus.ROTATED }),
      );
      const service = buildService(stubs);

      await expect(service.refresh('jeton-client', client)).rejects.toThrow(UnauthorizedException);
      expect(stubs.sessions.revokeSession).toHaveBeenCalledWith(
        'session-1',
        'refresh_reuse_detected',
      );
      expect(stubs.audit.record).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'auth.refresh_reuse_detected' }),
      );
      expect(stubs.sessions.rotateRefreshToken).not.toHaveBeenCalled();
    });

    it('session révoquée → 401 sans rotation', async () => {
      const stubs = buildStubs();
      stubs.sessions.findRefreshTokenByHash.mockResolvedValue(
        storedToken({}, { revokedAt: new Date() }),
      );
      const service = buildService(stubs);

      await expect(service.refresh('jeton-client', client)).rejects.toThrow(UnauthorizedException);
      expect(stubs.sessions.rotateRefreshToken).not.toHaveBeenCalled();
    });

    it('utilisateur supprimé → 401 même avec un jeton actif', async () => {
      const stubs = buildStubs();
      const stored = storedToken();
      stored.session.user.deletedAt = new Date();
      stubs.sessions.findRefreshTokenByHash.mockResolvedValue(stored);
      const service = buildService(stubs);

      await expect(service.refresh('jeton-client', client)).rejects.toThrow(UnauthorizedException);
      expect(stubs.sessions.rotateRefreshToken).not.toHaveBeenCalled();
    });

    it('rotation perdue (refresh concurrent) → traitée comme une réutilisation', async () => {
      const stubs = buildStubs();
      stubs.sessions.findRefreshTokenByHash.mockResolvedValue(storedToken());
      stubs.sessions.rotateRefreshToken.mockResolvedValue(false);
      const service = buildService(stubs);

      await expect(service.refresh('jeton-client', client)).rejects.toThrow(UnauthorizedException);
      expect(stubs.sessions.revokeSession).toHaveBeenCalledWith(
        'session-1',
        'refresh_reuse_detected',
      );
    });

    it('nominal : nouveau couple de jetons, expiration glissante', async () => {
      const stubs = buildStubs();
      stubs.sessions.findRefreshTokenByHash.mockResolvedValue(storedToken());
      const service = buildService(stubs);

      const tokens = await service.refresh('jeton-client', client);

      expect(tokens.refreshToken).toBe('nouveau-jeton');
      expect(tokens.accessToken).toBe('jwt');
      expect(stubs.sessions.rotateRefreshToken).toHaveBeenCalledWith(
        'token-1',
        'session-1',
        'hash-du-nouveau-jeton',
        expect.any(Date),
      );
    });
  });

  describe('forgotPassword', () => {
    it('compte inconnu : aucune création ni e-mail, mais la requête aboutit', async () => {
      const stubs = buildStubs();
      stubs.users.findActiveByEmail.mockResolvedValue(null);
      const service = buildService(stubs);

      await expect(service.forgotPassword('inconnu@b.fr', client)).resolves.toBeUndefined();
      expect(stubs.verifications.createPasswordReset).not.toHaveBeenCalled();
      expect(stubs.email.sendPasswordReset).not.toHaveBeenCalled();
    });
  });

  describe('changePassword', () => {
    it('mot de passe actuel erroné → 401 sans mise à jour ni révocation', async () => {
      const stubs = buildStubs();
      stubs.users.findPasswordHash.mockResolvedValue('$argon2id$reel');
      stubs.passwords.verify.mockResolvedValue(false);
      const service = buildService(stubs);

      await expect(
        service.changePassword('user-1', 'session-1', 'mauvais', 'x'.repeat(10), client),
      ).rejects.toThrow(UnauthorizedException);
      expect(stubs.users.updatePasswordHash).not.toHaveBeenCalled();
      expect(stubs.sessions.revokeAllSessions).not.toHaveBeenCalled();
    });

    it('nominal : met à jour le hash et révoque les autres sessions', async () => {
      const stubs = buildStubs();
      stubs.users.findPasswordHash.mockResolvedValue('$argon2id$reel');
      stubs.passwords.verify.mockResolvedValue(true);
      const service = buildService(stubs);

      await service.changePassword('user-1', 'session-1', 'actuel', 'x'.repeat(10), client);

      expect(stubs.users.updatePasswordHash).toHaveBeenCalled();
      expect(stubs.sessions.revokeAllSessions).toHaveBeenCalledWith(
        'user-1',
        'password_changed',
        'session-1',
      );
    });
  });
});
