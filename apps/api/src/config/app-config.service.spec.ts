import { type ConfigService } from '@nestjs/config';
import { AppConfigService } from './app-config.service';
import { type Env } from './env.schema';

const configOf = (values: Partial<Record<keyof Env, unknown>>) =>
  new AppConfigService({
    get: (key: keyof Env) => values[key],
  } as unknown as ConfigService<Env, true>);

describe('AppConfigService.swaggerEnabled', () => {
  it('jamais sur un serveur : SWAGGER_ENABLED=true ne publie pas /api/docs en production', () => {
    expect(configOf({ NODE_ENV: 'production', SWAGGER_ENABLED: true }).swaggerEnabled).toBe(false);
  });

  it('en développement : actif par défaut, éteint sur demande', () => {
    expect(configOf({ NODE_ENV: 'development' }).swaggerEnabled).toBe(true);
    expect(configOf({ NODE_ENV: 'development', SWAGGER_ENABLED: false }).swaggerEnabled).toBe(
      false,
    );
  });
});

describe('AppConfigService.logFingerprintKey', () => {
  const JWT = 'secret-jwt-de-test-32-caracteres-minimum';
  const DEDIEE = 'cle-dediee-de-test-32-caracteres-minimum';

  it('sans clé dédiée : la dérivation d’avant, depuis le secret JWT', () => {
    expect(configOf({ JWT_ACCESS_SECRET: JWT }).logFingerprintKey.toString('hex')).toBe(
      'e58c308feda693451f34e46d7c7b1f13f4cfd9d32e64407fe3976afe2e95e759',
    );
  });

  it('avec la clé dédiée : la rotation du secret JWT ne change plus les empreintes', () => {
    const avant = configOf({ JWT_ACCESS_SECRET: JWT, LOG_FINGERPRINT_SECRET: DEDIEE });
    const apres = configOf({ JWT_ACCESS_SECRET: `${JWT}-tourne`, LOG_FINGERPRINT_SECRET: DEDIEE });
    expect(apres.logFingerprintKey).toEqual(avant.logFingerprintKey);
    expect(avant.logFingerprintKey).not.toEqual(
      configOf({ JWT_ACCESS_SECRET: JWT }).logFingerprintKey,
    );
  });
});
