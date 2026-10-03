import { Injectable, UnauthorizedException } from '@nestjs/common';
import { type RequestClientContext } from '../../../common/types/authenticated-request';
import { AppConfigService } from '../../../config/app-config.service';
import { EmailService } from '../../../infrastructure/email/email.service';
import { AuditService } from '../../audit/audit.service';
import { UsersRepository } from '../../users/infrastructure/users.repository';
import { VerificationRepository } from '../infrastructure/verification.repository';
import { TokenService } from './token.service';

/**
 * Cadence des RENVOIS du lien de vérification, par compte. L'inscription
 * n'exige pas de vérifier l'adresse : sans cette cadence, quelqu'un
 * s'inscrivait avec l'adresse d'une victime et appelait le renvoi en boucle,
 * un vrai courrier Carlys par appel (mesuré : 40 appels, 40 e-mails, 41 liens
 * valides). La victime était inondée, et la réputation d'envoi du domaine —
 * celle dont dépend la réinitialisation de mot de passe de tout le monde —
 * avec elle.
 */
const EMAIL_VERIFICATION_CADENCE = {
  cooldownMs: 60_000,
  maxPerWindow: 5,
  windowMs: 24 * 3_600_000,
} as const;

/** Le lien de vérification d'adresse : premier envoi, renvois, validation. */
@Injectable()
export class EmailVerificationService {
  constructor(
    private readonly users: UsersRepository,
    private readonly verifications: VerificationRepository,
    private readonly tokens: TokenService,
    private readonly email: EmailService,
    private readonly audit: AuditService,
    private readonly config: AppConfigService,
  ) {}

  /** Le premier lien, à l'inscription. */
  async sendFirst(userId: string, email: string): Promise<void> {
    const verification = this.newToken();
    await this.verifications.createEmailVerification(
      userId,
      verification.tokenHash,
      verification.expiresAt,
    );
    this.email.sendEmailVerification(email, verification.token);
  }

  /**
   * (Ré)envoie le lien pour l'utilisateur connecté, au rythme de
   * [EMAIL_VERIFICATION_CADENCE] ; chaque nouveau lien invalide les
   * précédents. La réponse est la même que le lien parte ou non : rien à
   * apprendre en insistant.
   */
  async resend(userId: string, client: RequestClientContext): Promise<void> {
    const user = await this.users.findActiveById(userId);
    if (user === null || user.emailVerifiedAt !== null) {
      return;
    }
    const verification = this.newToken();
    const issued = await this.verifications.issueEmailVerification(
      user.id,
      verification.tokenHash,
      verification.expiresAt,
      EMAIL_VERIFICATION_CADENCE,
    );
    if (!issued) {
      this.audit.record({ action: 'auth.email_verification_resend_throttled', userId, ...client });
      return;
    }
    this.email.sendEmailVerification(user.email, verification.token);
    this.audit.record({ action: 'auth.email_verification_resent', userId, ...client });
  }

  async verify(token: string, client: RequestClientContext): Promise<void> {
    const record = await this.verifications.findEmailVerification(TokenService.hashToken(token));
    const valid =
      record !== null && record.usedAt === null && record.expiresAt.getTime() > Date.now();
    if (!valid || !(await this.verifications.claimEmailVerification(record.id))) {
      throw new UnauthorizedException('Lien de vérification invalide ou expiré.');
    }
    await this.users.markEmailVerified(record.userId);
    this.audit.record({ action: 'auth.email_verified', userId: record.userId, ...client });
  }

  private newToken(): ReturnType<TokenService['generateOpaqueToken']> {
    return this.tokens.generateOpaqueToken(this.config.emailVerificationTtlHours * 3_600_000);
  }
}
