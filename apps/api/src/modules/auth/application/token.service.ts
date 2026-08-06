import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes } from 'node:crypto';
import { AppConfigService } from '../../../config/app-config.service';

export interface GeneratedRefreshToken {
  /** Valeur en clair, remise une seule fois au client. */
  token: string;
  /** Hash SHA-256 hexadécimal — seule forme persistée. */
  tokenHash: string;
  expiresAt: Date;
}

/**
 * Fabrique des jetons :
 *  - access token JWT court (claims sub + sid, issuer/audience vérifiés) ;
 *  - refresh token opaque 256 bits, stocké uniquement sous forme de hash.
 */
@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: AppConfigService,
  ) {}

  signAccessToken(userId: string, sessionId: string): Promise<string> {
    return this.jwt.signAsync(
      { sid: sessionId },
      {
        subject: userId,
        secret: this.config.jwtAccessSecret,
        issuer: this.config.jwtIssuer,
        audience: this.config.jwtAudience,
        expiresIn: this.config.jwtAccessTtlSeconds,
      },
    );
  }

  generateRefreshToken(): GeneratedRefreshToken {
    const token = randomBytes(32).toString('base64url');
    return {
      token,
      tokenHash: TokenService.hashToken(token),
      expiresAt: new Date(Date.now() + this.config.refreshTokenTtlDays * 24 * 60 * 60 * 1_000),
    };
  }

  /** Jeton opaque pour e-mails (vérification, réinitialisation). */
  generateOpaqueToken(ttlMs: number): GeneratedRefreshToken {
    const token = randomBytes(32).toString('base64url');
    return {
      token,
      tokenHash: TokenService.hashToken(token),
      expiresAt: new Date(Date.now() + ttlMs),
    };
  }

  static hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
