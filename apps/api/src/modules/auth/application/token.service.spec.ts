import { JwtService } from '@nestjs/jwt';
import { type AppConfigService } from '../../../config/app-config.service';
import { TokenService } from './token.service';

const SECRET = 'secret-de-test-uniquement-32-caracteres-mini';

function configStub(): AppConfigService {
  return {
    jwtAccessSecret: SECRET,
    jwtAccessTtlSeconds: 900,
    jwtIssuer: 'carlys-api',
    jwtAudience: 'carlys-mobile',
    refreshTokenTtlDays: 30,
  } as unknown as AppConfigService;
}

describe('TokenService', () => {
  let service: TokenService;
  let jwtService: JwtService;

  beforeEach(() => {
    jwtService = new JwtService({});
    service = new TokenService(jwtService, configStub());
  });

  it('signe un access token portant sub, sid, issuer et audience', async () => {
    const token = await service.signAccessToken('user-1', 'session-1');

    const payload = jwtService.verify<{
      sub: string;
      sid: string;
      iss: string;
      aud: string;
      exp: number;
      iat: number;
    }>(token, {
      secret: SECRET,
      issuer: 'carlys-api',
      audience: 'carlys-mobile',
    });

    expect(payload.sub).toBe('user-1');
    expect(payload.sid).toBe('session-1');
    expect(payload.exp - payload.iat).toBe(900);
  });

  it('refuse la vérification avec une mauvaise audience', async () => {
    const token = await service.signAccessToken('user-1', 'session-1');

    expect(() => {
      jwtService.verify(token, { secret: SECRET, audience: 'autre-app' });
    }).toThrow();
  });

  it('génère des refresh tokens opaques uniques, jamais stockés en clair', () => {
    const first = service.generateRefreshToken();
    const second = service.generateRefreshToken();

    expect(first.token).not.toBe(second.token);
    expect(first.tokenHash).not.toBe(second.tokenHash);
    // 32 octets en base64url ≈ 43 caractères.
    expect(first.token.length).toBeGreaterThanOrEqual(42);
    expect(first.tokenHash).toBe(TokenService.hashToken(first.token));
    expect(first.tokenHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('applique la durée de vie configurée du refresh token (30 jours)', () => {
    const before = Date.now();
    const generated = service.generateRefreshToken();
    const expectedMs = 30 * 24 * 60 * 60 * 1_000;

    expect(generated.expiresAt.getTime() - before).toBeGreaterThanOrEqual(expectedMs - 1_000);
    expect(generated.expiresAt.getTime() - before).toBeLessThanOrEqual(expectedMs + 1_000);
  });

  it('hashToken est stable et déterministe (SHA-256)', () => {
    expect(TokenService.hashToken('abc')).toBe(TokenService.hashToken('abc'));
    expect(TokenService.hashToken('abc')).not.toBe(TokenService.hashToken('abd'));
  });
});
