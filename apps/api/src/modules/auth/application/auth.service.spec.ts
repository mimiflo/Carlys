import { ConflictException, HttpException, UnauthorizedException } from '@nestjs/common';
import { RefreshTokenStatus, UserStatus } from '@prisma/client';
import { logFingerprint } from '../../../common/utilities/log-privacy';
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
import { type EmailVerificationService } from './email-verification.service';
import { type LockoutService } from './lockout.service';
import { type PasswordService } from './password.service';
import { ReauthenticationService } from './reauthentication.service';
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
      | 'upsertPasswordHash'
    >
  >;
  sessions: jest.Mocked<
    Pick<
      SessionsRepository,
      'findRefreshTokenByHash' | 'rotateRefreshToken' | 'revokeSession' | 'revokeAllSessions'
    >
  >;
  verifications: jest.Mocked<
    Pick<
      VerificationRepository,
      'issuePasswordReset' | 'findPasswordReset' | 'invalidateOpenPasswordResets'
    >
  >;
  sessionsService: jest.Mocked<Pick<SessionsService, 'open'>>;
  passwords: jest.Mocked<Pick<PasswordService, 'hash' | 'verify'>>;
  tokens: {
    generateRefreshToken: jest.Mock;
    generateOpaqueToken: jest.Mock;
    signAccessToken: jest.Mock;
  };
  lockout: jest.Mocked<Pick<LockoutService, 'reserveAttempt' | 'reset'>>;
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
      upsertPasswordHash: jest.fn().mockResolvedValue(undefined),
    },
    sessions: {
      findRefreshTokenByHash: jest.fn(),
      rotateRefreshToken: jest.fn().mockResolvedValue(true),
      revokeSession: jest.fn().mockResolvedValue(undefined),
      revokeAllSessions: jest.fn().mockResolvedValue(undefined),
    },
    verifications: {
      issuePasswordReset: jest.fn().mockResolvedValue(true),
      findPasswordReset: jest.fn(),
      invalidateOpenPasswordResets: jest.fn().mockResolvedValue(undefined),
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
      reserveAttempt: jest.fn().mockResolvedValue({ locked: false }),
      reset: jest.fn().mockResolvedValue(undefined),
    },
    email: {
      sendEmailVerification: jest.fn(),
      sendPasswordReset: jest.fn(),
    },
    audit: { record: jest.fn() },
  };
}

const CLE_EMPREINTE = Buffer.from('cle-des-empreintes-de-test');

function buildService(stubs: Stubs): AuthService {
  const config = {
    jwtAccessTtlSeconds: 900,
    passwordResetTtlMinutes: 60,
    emailVerificationTtlHours: 24,
    logFingerprintKey: CLE_EMPREINTE,
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
    new ReauthenticationService(
      stubs.passwords as unknown as PasswordService,
      stubs.lockout as unknown as LockoutService,
    ),
    { sendFirst: jest.fn().mockResolvedValue(undefined) } as unknown as EmailVerificationService,
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
        friendCode: 'AC23DEF4',
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
      stubs.lockout.reserveAttempt.mockResolvedValue({ locked: true, retryAfterSeconds: 300 });
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
      // L'essai est compté AVANT la vérification, sous l'adresse normalisée.
      expect(stubs.lockout.reserveAttempt).toHaveBeenCalledWith('inconnu@b.fr');
      expect(stubs.lockout.reset).not.toHaveBeenCalled();
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
      expect(stubs.lockout.reserveAttempt).toHaveBeenCalledWith('a@b.fr');
      expect(stubs.lockout.reset).not.toHaveBeenCalled();
      expect(stubs.sessionsService.open).not.toHaveBeenCalled();
    });

    // L'audit survit à la suppression et à la purge du compte : l'adresse
    // saisie n'y entre qu'en empreinte, jamais en clair.
    it("l'audit d'un échec ou d'un verrou ne garde que l'empreinte de l'adresse", async () => {
      const stubs = buildStubs();
      stubs.users.findActiveByEmail.mockResolvedValue(null);
      const service = buildService(stubs);
      await expect(
        service.login({ email: 'Alice@B.fr', password: 'x'.repeat(10) }, client),
      ).rejects.toThrow(GENERIC_MESSAGE);
      stubs.lockout.reserveAttempt.mockResolvedValue({ locked: true, retryAfterSeconds: 300 });
      await expect(
        service.login({ email: 'Alice@B.fr', password: 'x'.repeat(10) }, client),
      ).rejects.toThrow(HttpException);

      const entries = stubs.audit.record.mock.calls.map(([entry]) => entry);
      expect(entries.map((entry) => entry.action)).toEqual([
        'auth.login_failed',
        'auth.login_blocked_lockout',
      ]);
      for (const entry of entries) {
        expect(entry.metadata).toEqual({ emailHash: logFingerprint('alice@b.fr', CLE_EMPREINTE) });
        expect(JSON.stringify(entry)).not.toContain('alice@b.fr');
      }
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
      expect(stubs.verifications.issuePasswordReset).not.toHaveBeenCalled();
      expect(stubs.email.sendPasswordReset).not.toHaveBeenCalled();
    });

    it('cadence du compte atteinte : aucun e-mail, audit, et la même réponse', async () => {
      const stubs = buildStubs();
      stubs.users.findActiveByEmail.mockResolvedValue({ id: 'user-1', email: 'a@b.fr' } as never);
      stubs.verifications.issuePasswordReset.mockResolvedValue(false);
      const service = buildService(stubs);

      await expect(service.forgotPassword('A@b.fr', client)).resolves.toBeUndefined();
      expect(stubs.email.sendPasswordReset).not.toHaveBeenCalled();
      expect(stubs.audit.record).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'auth.password_reset_throttled', userId: 'user-1' }),
      );
    });

    it('lien posé à la cadence de la réinitialisation : la fenêtre dure la validité d’un lien', async () => {
      const stubs = buildStubs();
      stubs.users.findActiveByEmail.mockResolvedValue({ id: 'user-1', email: 'a@b.fr' } as never);
      const service = buildService(stubs);

      await service.forgotPassword('a@b.fr', client);

      expect(stubs.verifications.issuePasswordReset).toHaveBeenCalledWith(
        'user-1',
        expect.any(String),
        expect.any(Date),
        { cooldownMs: 60_000, maxPerWindow: 5, windowMs: 60 * 60_000 },
      );
      expect(stubs.email.sendPasswordReset).toHaveBeenCalledWith('a@b.fr', expect.any(String));
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
      expect(stubs.users.upsertPasswordHash).not.toHaveBeenCalled();
      expect(stubs.sessions.revokeAllSessions).not.toHaveBeenCalled();
    });

    it('nominal : met à jour le hash et révoque les autres sessions', async () => {
      const stubs = buildStubs();
      stubs.users.findPasswordHash.mockResolvedValue('$argon2id$reel');
      stubs.passwords.verify.mockResolvedValue(true);
      const service = buildService(stubs);

      await service.changePassword('user-1', 'session-1', 'actuel', 'x'.repeat(10), client);

      expect(stubs.users.upsertPasswordHash).toHaveBeenCalled();
      expect(stubs.sessions.revokeAllSessions).toHaveBeenCalledWith(
        'user-1',
        'password_changed',
        'session-1',
      );
    });

    it('évince POUR DE BON : les liens de réinitialisation ouverts tombent aussi', async () => {
      // Le scénario que ce test ferme. Quelqu'un a eu accès à la boîte mail,
      // a demandé un lien de réinitialisation et ne s'en est pas encore
      // servi. La victime change son mot de passe pour le chasser : les
      // sessions tombent bien, mais le lien restait valide et le ramenait.
      // `resetPassword` et la liaison sociale appliquaient déjà cet
      // invariant ; ce chemin l'oubliait.
      const stubs = buildStubs();
      stubs.users.findPasswordHash.mockResolvedValue('$argon2id$reel');
      stubs.passwords.verify.mockResolvedValue(true);
      const service = buildService(stubs);

      await service.changePassword('user-1', 'session-1', 'actuel', 'x'.repeat(10), client);

      expect(stubs.verifications.invalidateOpenPasswordResets).toHaveBeenCalledWith('user-1');
    });

    it('mot de passe actuel erroné : aucun lien n’est invalidé', async () => {
      const stubs = buildStubs();
      stubs.users.findPasswordHash.mockResolvedValue('$argon2id$reel');
      stubs.passwords.verify.mockResolvedValue(false);
      const service = buildService(stubs);

      await expect(
        service.changePassword('user-1', 'session-1', 'faux', 'x'.repeat(10), client),
      ).rejects.toThrow(UnauthorizedException);

      expect(stubs.verifications.invalidateOpenPasswordResets).not.toHaveBeenCalled();
    });

    it('chaque échec compte au verrouillage de RE-authentification, pas à celui de la connexion', async () => {
      const stubs = buildStubs();
      stubs.users.findPasswordHash.mockResolvedValue('$argon2id$reel');
      stubs.passwords.verify.mockResolvedValue(false);
      const service = buildService(stubs);

      await expect(
        service.changePassword('user-1', 'session-1', 'faux', 'x'.repeat(10), client),
      ).rejects.toThrow(UnauthorizedException);

      expect(stubs.lockout.reserveAttempt).toHaveBeenCalledWith('reauth:user-1');
      expect(stubs.lockout.reset).not.toHaveBeenCalled();
    });

    it('compte verrouillé : 429 sans même vérifier le mot de passe, juste ou non', async () => {
      const stubs = buildStubs();
      stubs.users.findPasswordHash.mockResolvedValue('$argon2id$reel');
      stubs.passwords.verify.mockResolvedValue(true);
      stubs.lockout.reserveAttempt.mockResolvedValue({ locked: true, retryAfterSeconds: 600 });
      const service = buildService(stubs);

      const error: unknown = await service
        .changePassword('user-1', 'session-1', 'actuel', 'x'.repeat(10), client)
        .catch((caught: unknown) => caught);

      expect(error).toBeInstanceOf(HttpException);
      expect((error as HttpException).getStatus()).toBe(429);
      expect(stubs.passwords.verify).not.toHaveBeenCalled();
      expect(stubs.users.upsertPasswordHash).not.toHaveBeenCalled();
    });
  });
});
