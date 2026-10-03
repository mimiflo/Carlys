import { ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AppConfigService } from '../../../config/app-config.service';
import { AdminRepository, type AdminWithAccess } from '../infrastructure/admin.repository';
import { verifyTotp } from './totp';
import { openTotpSecret, totpVaultKey } from './totp-vault';

/** Audience du jeton de la PREMIÈRE étape : jamais accepté comme session. */
export const ADMIN_MFA_AUDIENCE = 'carlys-admin-mfa';
/** Le temps de sortir son téléphone et de recopier un code, pas davantage. */
const CHALLENGE_TTL_SECONDS = 5 * 60;

export const EXPIRED_CHALLENGE_MESSAGE = 'Étape expirée : reconnecte-toi avec ton mot de passe.';
export const TOTP_NOT_ISSUED_MESSAGE =
  'Double authentification pas encore configurée pour ce compte : l’opérateur du serveur doit lancer « carlysctl admin-create <env> <email> --reset-2fa ».';

/**
 * La seconde étape de la connexion au back-office : le code à 6 chiffres
 * d'une appli d'authentification (TOTP, RFC 6238). Le mot de passe seul
 * n'ouvre plus rien : un mot de passe volé ne suffit pas.
 *
 * Le secret ne s'émet JAMAIS ici : un QR code montré par la page de
 * connexion irait au premier qui connaît le mot de passe — l'intrus compris,
 * qui verrouillerait alors le vrai propriétaire dehors. Il s'émet sur le
 * terminal du serveur (`admin-bootstrap`), réservé à qui en a la clé SSH.
 */
@Injectable()
export class AdminTotpService {
  constructor(
    private readonly admins: AdminRepository,
    private readonly jwt: JwtService,
    private readonly config: AppConfigService,
  ) {}

  /** Après un mot de passe juste : le jeton de la seconde étape, ou 403 sans secret émis. */
  async challengeFor(admin: AdminWithAccess): Promise<{ challengeToken: string }> {
    if (admin.totpSecret === null) throw new ForbiddenException(TOTP_NOT_ISSUED_MESSAGE);
    const challengeToken = await this.jwt.signAsync(
      { mfa: 'pending' },
      {
        subject: admin.id,
        secret: this.config.jwtAccessSecret,
        issuer: this.config.jwtIssuer,
        audience: ADMIN_MFA_AUDIENCE,
        expiresIn: CHALLENGE_TTL_SECONDS,
      },
    );
    return { challengeToken };
  }

  /** L'administrateur du jeton de première étape, ou 401. */
  async adminIdOf(challengeToken: string): Promise<string> {
    try {
      const payload = await this.jwt.verifyAsync<{ sub?: unknown; mfa?: unknown }>(challengeToken, {
        secret: this.config.jwtAccessSecret,
        algorithms: ['HS256'],
        issuer: this.config.jwtIssuer,
        audience: ADMIN_MFA_AUDIENCE,
      });
      if (payload.mfa === 'pending' && typeof payload.sub === 'string') return payload.sub;
    } catch {
      // Expiré, altéré ou d'une autre audience : même réponse.
    }
    throw new UnauthorizedException(EXPIRED_CHALLENGE_MESSAGE);
  }

  /**
   * Le code est-il juste, et ENCORE inutilisé ? Consommé s'il l'est (l'enrôlement
   * en attente se confirme du même coup) : `false` sinon, sans dire pourquoi.
   */
  async consumeCode(admin: AdminWithAccess, code: string, now = new Date()): Promise<boolean> {
    const sealed = admin.totpSecret;
    if (sealed === null) return false;
    const secret = openTotpSecret(sealed, totpVaultKey(this.config.jwtAccessSecret), admin.id);
    if (secret === null) return false;
    const step = verifyTotp(secret, code, Math.floor(now.getTime() / 1000), admin.totpLastStep);
    if (step === null) return false;
    return this.admins.claimTotpStep(admin.id, sealed, step, admin.totpEnabledAt ?? now);
  }
}
