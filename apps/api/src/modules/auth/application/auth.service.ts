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
import { logFingerprint } from '../../../common/utilities/log-privacy';
import { AppConfigService } from '../../../config/app-config.service';
import { EmailService } from '../../../infrastructure/email/email.service';
import { AuditService } from '../../audit/audit.service';
import { UsersRepository } from '../../users/infrastructure/users.repository';
import { SessionsRepository } from '../infrastructure/sessions.repository';
import { VerificationRepository } from '../infrastructure/verification.repository';
import { EmailVerificationService } from './email-verification.service';
import { LockoutService, lockoutMessage } from './lockout.service';
import { passwordResetCadence } from './password-reset-cadence';
import { PasswordService } from './password.service';
import { reauthLockoutKey, ReauthenticationService } from './reauthentication.service';
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
    private readonly reauth: ReauthenticationService,
    private readonly emailVerification: EmailVerificationService,
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

    await this.emailVerification.sendFirst(user.id, email);
    this.audit.record({ action: 'auth.registered', userId: user.id, ...client });

    const tokens = await this.sessionsService.open(user.id, input, client);
    return { user: presentUser(user), tokens };
  }

  async login(
    input: { email: string; password: string } & DeviceInfo,
    client: RequestClientContext,
  ): Promise<AuthResult> {
    const email = normalizeEmail(input.email);

    // L'essai est RÉSERVÉ avant la vérification : lire puis compter après
    // laissait passer toute une rafale simultanée (LockoutService.reserveAttempt).
    const lock = await this.lockout.reserveAttempt(email);
    // L'audit n'est PAS effacé avec le compte : l'adresse saisie n'y entre
    // qu'en empreinte, sans quoi elle survivait en clair à la suppression et
    // à la purge (docs/legal/privacy.md, « Combien de temps »).
    const emailHash = logFingerprint(email, this.config.logFingerprintKey);
    if (lock.locked) {
      this.audit.record({
        action: 'auth.login_blocked_lockout',
        ...client,
        metadata: { emailHash },
      });
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
      this.audit.record({
        action: 'auth.login_failed',
        userId: user?.id,
        ...client,
        metadata: { emailHash },
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

  /**
   * Réponse identique que le compte existe ou non, et que le lien parte ou
   * non : aucune énumération possible. Au rythme de [passwordResetCadence].
   */
  async forgotPassword(email: string, client: RequestClientContext): Promise<void> {
    const user = await this.users.findActiveByEmail(normalizeEmail(email));
    if (user === null) {
      this.audit.record({ action: 'auth.password_reset_requested_unknown', ...client });
      return;
    }
    const ttlMinutes = this.config.passwordResetTtlMinutes;
    const reset = this.tokens.generateOpaqueToken(ttlMinutes * 60_000);
    const issued = await this.verifications.issuePasswordReset(
      user.id,
      reset.tokenHash,
      reset.expiresAt,
      passwordResetCadence(ttlMinutes),
    );
    if (!issued) {
      this.audit.record({ action: 'auth.password_reset_throttled', userId: user.id, ...client });
      return;
    }
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
    // Consommé AVANT d'agir : de deux requêtes simultanées, une seule passe.
    if (!valid || !(await this.verifications.claimPasswordReset(record.id))) {
      throw new UnauthorizedException('Lien de réinitialisation invalide ou expiré.');
    }
    await this.users.upsertPasswordHash(record.userId, await this.passwords.hash(newPassword));
    await this.verifications.invalidateOpenPasswordResets(record.userId);
    // Le mot de passe a pu être compromis : toutes les sessions tombent.
    await this.sessions.revokeAllSessions(record.userId, 'password_reset');
    await this.lockout.reset((await this.users.findActiveById(record.userId))?.email ?? '');
    // Le compteur des RE-authentifications aussi : sinon, les essais faux
    // d'un voleur de session — chassé à l'instant — interdisaient au
    // propriétaire, qui vient de prouver qu'il tient la boîte mail, de
    // supprimer son compte ou de changer son mot de passe (429) jusqu'à la
    // fin de la fenêtre.
    await this.lockout.reset(reauthLockoutKey(record.userId));
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
    // Verrouillage des re-authentifications : sans lui, cette route était un
    // oracle de mot de passe sans plafond par compte (ReauthenticationService).
    if (
      passwordHash === null ||
      !(await this.reauth.verify(userId, passwordHash, currentPassword))
    ) {
      this.audit.record({ action: 'auth.password_change_failed', userId, ...client });
      throw new UnauthorizedException('Mot de passe actuel incorrect.');
    }
    await this.users.upsertPasswordHash(userId, await this.passwords.hash(newPassword));
    // Les liens de réinitialisation encore ouverts tombent AVEC le mot de
    // passe. Sans cela, changer son mot de passe n'évinçait qu'à moitié :
    // quelqu'un qui a eu accès à la boîte mail demande un lien et ne s'en sert
    // pas ; la victime change son mot de passe pour le chasser, les sessions
    // tombent — mais le lien reste valide et le ramène. `resetPassword` et la
    // liaison sociale appliquent déjà cet invariant ; ce chemin l'oubliait.
    await this.verifications.invalidateOpenPasswordResets(userId);
    // Les autres appareils doivent se reconnecter ; la session courante survit.
    await this.sessions.revokeAllSessions(userId, 'password_changed', sessionId);
    this.audit.record({ action: 'auth.password_changed', userId, ...client });
  }
}
