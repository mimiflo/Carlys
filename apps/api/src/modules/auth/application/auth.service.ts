import { type AuthResult, type AuthTokens } from '@carlys/api-contracts';
import {
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { RefreshTokenStatus, UserStatus } from '@prisma/client';
import { type RequestClientContext } from '../../../common/types/authenticated-request';
import { AppConfigService } from '../../../config/app-config.service';
import { EmailService } from '../../../infrastructure/email/email.service';
import { AuditService } from '../../audit/audit.service';
import { UsersRepository } from '../../users/infrastructure/users.repository';
import { SessionsRepository } from '../infrastructure/sessions.repository';
import { VerificationRepository } from '../infrastructure/verification.repository';
import { LockoutService, lockoutMessage } from './lockout.service';
import { PasswordService } from './password.service';
import { type DeviceInfo, SessionsService } from './sessions.service';
import { TokenService } from './token.service';
import { presentUser } from './user.presenter';

const INVALID_CREDENTIALS_MESSAGE = 'E-mail ou mot de passe incorrect.';

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersRepository,
    private readonly sessions: SessionsRepository,
    private readonly verifications: VerificationRepository,
    private readonly sessionsService: SessionsService,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
    private readonly lockout: LockoutService,
    private readonly email: EmailService,
    private readonly audit: AuditService,
    private readonly config: AppConfigService,
  ) {}

  async register(
    input: { email: string; password: string; displayName: string } & DeviceInfo,
    client: RequestClientContext,
  ): Promise<AuthResult> {
    const email = normalizeEmail(input.email);
    if ((await this.users.emailExists(email)) !== null) {
      throw new ConflictException('Un compte existe déjà avec cette adresse e-mail.');
    }

    const passwordHash = await this.passwords.hash(input.password);
    const user = await this.users.create({
      email,
      passwordHash,
      displayName: input.displayName.trim(),
    });

    await this.sendEmailVerification(user.id, email);
    this.audit.record({ action: 'auth.registered', userId: user.id, ...client });

    const tokens = await this.sessionsService.open(user.id, input, client);
    return { user: presentUser(user), tokens };
  }

  async login(
    input: { email: string; password: string } & DeviceInfo,
    client: RequestClientContext,
  ): Promise<AuthResult> {
    const email = normalizeEmail(input.email);

    const lock = await this.lockout.status(email);
    if (lock.locked) {
      this.audit.record({ action: 'auth.login_blocked_lockout', ...client, metadata: { email } });
      throw new HttpException(lockoutMessage(lock), HttpStatus.TOO_MANY_REQUESTS);
    }

    const user = await this.users.findActiveByEmail(email);
    const passwordHash = user === null ? null : await this.users.findPasswordHash(user.id);
    // Vérification systématique (hash factice sinon) : temps de réponse
    // comparable que le compte existe ou non.
    const valid =
      passwordHash !== null
        ? await this.passwords.verify(passwordHash, input.password)
        : (await this.passwords.hash(input.password), false);

    if (!valid || user === null || user.status !== UserStatus.ACTIVE) {
      await this.lockout.recordFailure(email);
      this.audit.record({
        action: 'auth.login_failed',
        userId: user?.id,
        ...client,
        metadata: { email },
      });
      throw new UnauthorizedException(INVALID_CREDENTIALS_MESSAGE);
    }

    await this.lockout.reset(email);
    this.audit.record({ action: 'auth.login', userId: user.id, ...client });

    const tokens = await this.sessionsService.open(user.id, input, client);
    return { user: presentUser(user), tokens };
  }

  /** Rotation du refresh token, avec détection de réutilisation. */
  async refresh(refreshToken: string, client: RequestClientContext): Promise<AuthTokens> {
    const tokenHash = TokenService.hashToken(refreshToken);
    const stored = await this.sessions.findRefreshTokenByHash(tokenHash);
    if (stored === null) {
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    const { session } = stored;

    // Jeton déjà rotaté ou révoqué : quelqu'un rejoue un ancien jeton.
    // Toute la session est compromise → révocation immédiate.
    if (stored.status !== RefreshTokenStatus.ACTIVE) {
      if (session.revokedAt === null) {
        await this.sessions.revokeSession(session.id, 'refresh_reuse_detected');
      }
      this.audit.record({
        action: 'auth.refresh_reuse_detected',
        userId: session.userId,
        ...client,
        metadata: { sessionId: session.id },
      });
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    const now = Date.now();
    const usable =
      session.revokedAt === null &&
      session.expiresAt.getTime() > now &&
      stored.expiresAt.getTime() > now &&
      session.user.status === UserStatus.ACTIVE &&
      session.user.deletedAt === null;
    if (!usable) {
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    const next = this.tokens.generateRefreshToken();
    const rotated = await this.sessions.rotateRefreshToken(
      stored.id,
      session.id,
      next.tokenHash,
      next.expiresAt,
    );
    if (!rotated) {
      // Un refresh concurrent a consommé ce jeton entre la lecture et la
      // rotation : même traitement qu'une réutilisation.
      await this.sessions.revokeSession(session.id, 'refresh_reuse_detected');
      this.audit.record({
        action: 'auth.refresh_reuse_detected',
        userId: session.userId,
        ...client,
        metadata: { sessionId: session.id, concurrent: true },
      });
      throw new UnauthorizedException('Session expirée ou invalide.');
    }
    const accessToken = await this.tokens.signAccessToken(session.userId, session.id);

    return {
      accessToken,
      accessTokenExpiresIn: this.config.jwtAccessTtlSeconds,
      refreshToken: next.token,
      refreshTokenExpiresAt: next.expiresAt.toISOString(),
    };
  }

  async logout(userId: string, sessionId: string, client: RequestClientContext): Promise<void> {
    await this.sessions.revokeSession(sessionId, 'logout');
    this.audit.record({ action: 'auth.logout', userId, ...client, metadata: { sessionId } });
  }

  async verifyEmail(token: string, client: RequestClientContext): Promise<void> {
    const record = await this.verifications.findEmailVerification(TokenService.hashToken(token));
    const valid =
      record !== null && record.usedAt === null && record.expiresAt.getTime() > Date.now();
    if (!valid) {
      throw new UnauthorizedException('Lien de vérification invalide ou expiré.');
    }
    await this.verifications.markEmailVerificationUsed(record.id);
    await this.users.markEmailVerified(record.userId);
    this.audit.record({ action: 'auth.email_verified', userId: record.userId, ...client });
  }

  /** Réponse identique que le compte existe ou non — aucune énumération possible. */
  async forgotPassword(email: string, client: RequestClientContext): Promise<void> {
    const user = await this.users.findActiveByEmail(normalizeEmail(email));
    if (user === null) {
      this.audit.record({ action: 'auth.password_reset_requested_unknown', ...client });
      return;
    }
    const reset = this.tokens.generateOpaqueToken(this.config.passwordResetTtlMinutes * 60_000);
    await this.verifications.createPasswordReset(user.id, reset.tokenHash, reset.expiresAt);
    this.email.sendPasswordReset(user.email, reset.token);
    this.audit.record({ action: 'auth.password_reset_requested', userId: user.id, ...client });
  }

  async resetPassword(
    token: string,
    newPassword: string,
    client: RequestClientContext,
  ): Promise<void> {
    const record = await this.verifications.findPasswordReset(TokenService.hashToken(token));
    const valid =
      record !== null && record.usedAt === null && record.expiresAt.getTime() > Date.now();
    if (!valid) {
      throw new UnauthorizedException('Lien de réinitialisation invalide ou expiré.');
    }
    await this.users.updatePasswordHash(record.userId, await this.passwords.hash(newPassword));
    await this.verifications.markPasswordResetUsed(record.id);
    await this.verifications.invalidateOpenPasswordResets(record.userId);
    // Le mot de passe a pu être compromis : toutes les sessions tombent.
    await this.sessions.revokeAllSessions(record.userId, 'password_reset');
    await this.lockout.reset((await this.users.findActiveById(record.userId))?.email ?? '');
    this.audit.record({ action: 'auth.password_reset', userId: record.userId, ...client });
  }

  async changePassword(
    userId: string,
    sessionId: string,
    currentPassword: string,
    newPassword: string,
    client: RequestClientContext,
  ): Promise<void> {
    const passwordHash = await this.users.findPasswordHash(userId);
    if (passwordHash === null || !(await this.passwords.verify(passwordHash, currentPassword))) {
      this.audit.record({ action: 'auth.password_change_failed', userId, ...client });
      throw new UnauthorizedException('Mot de passe actuel incorrect.');
    }
    await this.users.updatePasswordHash(userId, await this.passwords.hash(newPassword));
    // Les autres appareils doivent se reconnecter ; la session courante survit.
    await this.sessions.revokeAllSessions(userId, 'password_changed', sessionId);
    this.audit.record({ action: 'auth.password_changed', userId, ...client });
  }

  /** (Ré)envoie l'e-mail de vérification pour l'utilisateur connecté. */
  async resendEmailVerification(userId: string, client: RequestClientContext): Promise<void> {
    const user = await this.users.findActiveById(userId);
    if (user === null || user.emailVerifiedAt !== null) {
      return;
    }
    await this.sendEmailVerification(user.id, user.email);
    this.audit.record({ action: 'auth.email_verification_resent', userId, ...client });
  }

  private async sendEmailVerification(userId: string, email: string): Promise<void> {
    const verification = this.tokens.generateOpaqueToken(
      this.config.emailVerificationTtlHours * 3_600_000,
    );
    await this.verifications.createEmailVerification(
      userId,
      verification.tokenHash,
      verification.expiresAt,
    );
    this.email.sendEmailVerification(email, verification.token);
  }
}
