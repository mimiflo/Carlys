import { type AuthSession, type AuthTokens } from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditService } from '../../audit/audit.service';
import { type RequestClientContext } from '../../../common/types/authenticated-request';
import { AppConfigService } from '../../../config/app-config.service';
import { SessionsRepository } from '../infrastructure/sessions.repository';
import { presentSession } from './user.presenter';
import { TokenService } from './token.service';

export interface DeviceInfo {
  deviceName?: string;
  devicePlatform?: string;
}

/** Cycle de vie des sessions par appareil : création, listing, révocation. */
@Injectable()
export class SessionsService {
  constructor(
    private readonly sessions: SessionsRepository,
    private readonly tokens: TokenService,
    private readonly config: AppConfigService,
    private readonly audit: AuditService,
  ) {}

  /** Ouvre une session pour l'appareil et retourne la paire de jetons. */
  async open(
    userId: string,
    device: DeviceInfo,
    client: RequestClientContext,
  ): Promise<AuthTokens> {
    const refresh = this.tokens.generateRefreshToken();
    const session = await this.sessions.create({
      userId,
      refreshTokenHash: refresh.tokenHash,
      expiresAt: refresh.expiresAt,
      deviceName: device.deviceName,
      devicePlatform: device.devicePlatform,
      ipAddress: client.ipAddress,
      userAgent: client.userAgent,
    });

    const accessToken = await this.tokens.signAccessToken(userId, session.id);
    return {
      accessToken,
      accessTokenExpiresIn: this.config.jwtAccessTtlSeconds,
      refreshToken: refresh.token,
      refreshTokenExpiresAt: refresh.expiresAt.toISOString(),
    };
  }

  async list(userId: string, currentSessionId: string): Promise<AuthSession[]> {
    const sessions = await this.sessions.listActiveSessions(userId);
    return sessions.map((session) => presentSession(session, currentSessionId));
  }

  /** Révoque une session appartenant à l'utilisateur (appareil ciblé). */
  async revokeOne(userId: string, sessionId: string, client: RequestClientContext): Promise<void> {
    const session = await this.sessions.findSessionById(sessionId);
    if (session === null || session.userId !== userId || session.revokedAt !== null) {
      throw new NotFoundException('Session introuvable.');
    }
    await this.sessions.revokeSession(sessionId, 'user_revoked');
    this.audit.record({
      action: 'auth.session_revoked',
      userId,
      ...client,
      metadata: { sessionId },
    });
  }

  /** Révoque toutes les autres sessions (déconnexion globale). */
  async revokeOthers(
    userId: string,
    currentSessionId: string,
    client: RequestClientContext,
  ): Promise<void> {
    await this.sessions.revokeAllSessions(userId, 'user_revoked_all', currentSessionId);
    this.audit.record({ action: 'auth.sessions_revoked_all', userId, ...client });
  }
}
