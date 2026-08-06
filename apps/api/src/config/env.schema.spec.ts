import { validateEnv } from './env.schema';

const validEnv = {
  DATABASE_URL: 'postgresql://user:password@localhost:5432/carlys_dev',
  REDIS_URL: 'redis://localhost:6379',
};

describe('validateEnv', () => {
  it('accepte une configuration minimale et applique les valeurs par défaut', () => {
    const env = validateEnv({ ...validEnv });

    expect(env.NODE_ENV).toBe('development');
    expect(env.PORT).toBe(3000);
    expect(env.LOG_LEVEL).toBe('info');
    expect(env.RATE_LIMIT_TTL_SECONDS).toBeGreaterThan(0);
    expect(env.SWAGGER_ENABLED).toBeUndefined();
  });

  it('refuse le démarrage sans DATABASE_URL', () => {
    expect(() => validateEnv({ REDIS_URL: validEnv.REDIS_URL })).toThrow(
      /Configuration invalide/,
    );
  });

  it('refuse une DATABASE_URL qui ne pointe pas vers PostgreSQL', () => {
    expect(() =>
      validateEnv({ ...validEnv, DATABASE_URL: 'mysql://localhost:3306/db' }),
    ).toThrow(/PostgreSQL/);
  });

  it('refuse une REDIS_URL invalide', () => {
    expect(() =>
      validateEnv({ ...validEnv, REDIS_URL: 'http://localhost' }),
    ).toThrow(/Redis/);
  });

  it('convertit PORT en nombre et rejette les valeurs hors bornes', () => {
    expect(validateEnv({ ...validEnv, PORT: '8080' }).PORT).toBe(8080);
    expect(() => validateEnv({ ...validEnv, PORT: '0' })).toThrow(
      /Configuration invalide/,
    );
    expect(() => validateEnv({ ...validEnv, PORT: 'abc' })).toThrow(
      /Configuration invalide/,
    );
  });

  it('interprète SWAGGER_ENABLED comme booléen strict', () => {
    expect(
      validateEnv({ ...validEnv, SWAGGER_ENABLED: 'true' }).SWAGGER_ENABLED,
    ).toBe(true);
    expect(
      validateEnv({ ...validEnv, SWAGGER_ENABLED: 'false' }).SWAGGER_ENABLED,
    ).toBe(false);
    expect(() => validateEnv({ ...validEnv, SWAGGER_ENABLED: 'yes' })).toThrow(
      /Configuration invalide/,
    );
  });

  it('exige un METRICS_TOKEN suffisamment long', () => {
    expect(() => validateEnv({ ...validEnv, METRICS_TOKEN: 'court' })).toThrow(
      /Configuration invalide/,
    );
    expect(
      validateEnv({ ...validEnv, METRICS_TOKEN: 'un-token-suffisamment-long' })
        .METRICS_TOKEN,
    ).toBe('un-token-suffisamment-long');
  });
});
