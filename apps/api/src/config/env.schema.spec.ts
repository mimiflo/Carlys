import { validateEnv } from './env.schema';

const validEnv = {
  DATABASE_URL: 'postgresql://user:password@localhost:5432/carlys_dev',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'secret-de-test-uniquement-32-caracteres-mini',
};

describe('validateEnv', () => {
  it('accepte une configuration minimale et applique les valeurs par défaut', () => {
    const env = validateEnv({ ...validEnv });

    expect(env.NODE_ENV).toBe('development');
    expect(env.PORT).toBe(3000);
    expect(env.LOG_LEVEL).toBe('info');
    expect(env.RATE_LIMIT_TTL_SECONDS).toBeGreaterThan(0);
    expect(env.SWAGGER_ENABLED).toBeUndefined();
    // Les liens des e-mails ouvrent des pages servies par l'admin Next.js
    // (3001), jamais par l'API (3000) — et cette origine est admise par CORS.
    expect(env.PUBLIC_APP_URL).toBe('http://localhost:3001');
    expect(env.CORS_ORIGINS.split(',')).toContain('http://localhost:3001');
  });

  it('refuse le démarrage sans DATABASE_URL', () => {
    const { DATABASE_URL: _omitted, ...withoutDatabase } = validEnv;
    expect(() => validateEnv(withoutDatabase)).toThrow(/Configuration invalide/);
  });

  it('refuse le démarrage sans JWT_ACCESS_SECRET ou avec un secret trop court', () => {
    const { JWT_ACCESS_SECRET: _omitted, ...withoutSecret } = validEnv;
    expect(() => validateEnv(withoutSecret)).toThrow(/Configuration invalide/);
    expect(() => validateEnv({ ...validEnv, JWT_ACCESS_SECRET: 'court' })).toThrow(/32 caractères/);
  });

  it('refuse une DATABASE_URL qui ne pointe pas vers PostgreSQL', () => {
    expect(() => validateEnv({ ...validEnv, DATABASE_URL: 'mysql://localhost:3306/db' })).toThrow(
      /PostgreSQL/,
    );
  });

  it('refuse une REDIS_URL invalide', () => {
    expect(() => validateEnv({ ...validEnv, REDIS_URL: 'http://localhost' })).toThrow(/Redis/);
  });

  it('convertit PORT en nombre et rejette les valeurs hors bornes', () => {
    expect(validateEnv({ ...validEnv, PORT: '8080' }).PORT).toBe(8080);
    expect(() => validateEnv({ ...validEnv, PORT: '0' })).toThrow(/Configuration invalide/);
    expect(() => validateEnv({ ...validEnv, PORT: 'abc' })).toThrow(/Configuration invalide/);
  });

  it('interprète SWAGGER_ENABLED comme booléen strict', () => {
    expect(validateEnv({ ...validEnv, SWAGGER_ENABLED: 'true' }).SWAGGER_ENABLED).toBe(true);
    expect(validateEnv({ ...validEnv, SWAGGER_ENABLED: 'false' }).SWAGGER_ENABLED).toBe(false);
    expect(() => validateEnv({ ...validEnv, SWAGGER_ENABLED: 'yes' })).toThrow(
      /Configuration invalide/,
    );
  });

  it('TRUST_PROXY_HOPS : 0 par défaut, entier positif ou nul, jamais « tout »', () => {
    expect(validateEnv({ ...validEnv }).TRUST_PROXY_HOPS).toBe(0);
    expect(validateEnv({ ...validEnv, TRUST_PROXY_HOPS: '1' }).TRUST_PROXY_HOPS).toBe(1);
    expect(() => validateEnv({ ...validEnv, TRUST_PROXY_HOPS: '-1' })).toThrow(
      /Configuration invalide/,
    );
    // `true` accepterait un X-Forwarded-For forgé : refusé dès la configuration.
    expect(() => validateEnv({ ...validEnv, TRUST_PROXY_HOPS: 'true' })).toThrow(
      /Configuration invalide/,
    );
  });

  it('exige un METRICS_TOKEN suffisamment long', () => {
    expect(() => validateEnv({ ...validEnv, METRICS_TOKEN: 'court' })).toThrow(
      /Configuration invalide/,
    );
    expect(
      validateEnv({ ...validEnv, METRICS_TOKEN: 'un-token-suffisamment-long' }).METRICS_TOKEN,
    ).toBe('un-token-suffisamment-long');
  });
});

/**
 * En production, une valeur de développement oubliée ne doit JAMAIS passer :
 * l'API démarrerait « avec succès » en envoyant ses e-mails dans le vide et
 * en servant des URL de médias vers localhost.
 */
describe('validateEnv en production', () => {
  // Toutes les valeurs sont factices : aucune n'ouvre quoi que ce soit.
  const productionEnv = {
    ...validEnv,
    NODE_ENV: 'production',
    CORS_ORIGINS: 'https://admin.carlys.example',
    S3_ENDPOINT: 'https://s3.exemple.invalid',
    S3_ACCESS_KEY_ID: 'cle-factice-production',
    S3_SECRET_ACCESS_KEY: 'secret-factice-production',
    S3_PUBLIC_BASE_URL: 'https://media.carlys.example',
    SMTP_HOST: 'smtp.exemple.invalid',
    EMAIL_FROM: 'Carlys <no-reply@carlys.example>',
    PUBLIC_APP_URL: 'https://app.carlys.example',
  };

  it('production sans S3 : démarrage refusé, chaque variable manquante nommée', () => {
    const {
      S3_ENDPOINT: _endpoint,
      S3_ACCESS_KEY_ID: _key,
      S3_SECRET_ACCESS_KEY: _secret,
      S3_PUBLIC_BASE_URL: _publicUrl,
      ...withoutS3
    } = productionEnv;

    expect(() => validateEnv(withoutS3)).toThrow(/Configuration invalide/);
    expect(() => validateEnv(withoutS3)).toThrow(/S3_ENDPOINT/);
    expect(() => validateEnv(withoutS3)).toThrow(/S3_ACCESS_KEY_ID/);
    expect(() => validateEnv(withoutS3)).toThrow(/S3_SECRET_ACCESS_KEY/);
    expect(() => validateEnv(withoutS3)).toThrow(/S3_PUBLIC_BASE_URL/);
  });

  it('production sans SMTP, sans URL publique ou sans CORS : refusé', () => {
    for (const key of ['SMTP_HOST', 'EMAIL_FROM', 'PUBLIC_APP_URL', 'CORS_ORIGINS'] as const) {
      const { [key]: _omitted, ...incomplete } = productionEnv;
      expect(() => validateEnv(incomplete)).toThrow(new RegExp(key));
    }
  });

  it('production complète : acceptée', () => {
    const env = validateEnv({ ...productionEnv });

    expect(env.NODE_ENV).toBe('production');
    expect(env.S3_PUBLIC_BASE_URL).toBe('https://media.carlys.example');
  });

  it('refuse localhost et 127.0.0.1 dans les URL publiques', () => {
    expect(() =>
      validateEnv({ ...productionEnv, PUBLIC_APP_URL: 'https://localhost:3000' }),
    ).toThrow(/PUBLIC_APP_URL.*localhost/);
    expect(() =>
      validateEnv({ ...productionEnv, S3_PUBLIC_BASE_URL: 'https://127.0.0.1/carlys-media' }),
    ).toThrow(/S3_PUBLIC_BASE_URL.*localhost/);
    expect(() =>
      validateEnv({
        ...productionEnv,
        CORS_ORIGINS: 'https://admin.carlys.example,http://localhost:3001',
      }),
    ).toThrow(/CORS_ORIGINS.*localhost/);
  });

  it('exige https:// pour S3_PUBLIC_BASE_URL et PUBLIC_APP_URL', () => {
    expect(() =>
      validateEnv({ ...productionEnv, PUBLIC_APP_URL: 'http://app.carlys.example' }),
    ).toThrow(/PUBLIC_APP_URL.*https/);
    expect(() =>
      validateEnv({ ...productionEnv, S3_PUBLIC_BASE_URL: 'http://media.carlys.example' }),
    ).toThrow(/S3_PUBLIC_BASE_URL.*https/);
  });

  it('refuse les identifiants de développement carlys-dev*', () => {
    expect(() => validateEnv({ ...productionEnv, S3_ACCESS_KEY_ID: 'carlys-dev-autre' })).toThrow(
      /S3_ACCESS_KEY_ID.*carlys-dev/,
    );
    expect(() =>
      validateEnv({ ...productionEnv, S3_SECRET_ACCESS_KEY: 'carlys-dev-secret-2' }),
    ).toThrow(/S3_SECRET_ACCESS_KEY.*carlys-dev/);
  });

  it('hors production, les défauts de développement restent acceptés', () => {
    for (const nodeEnv of ['development', 'test', 'staging']) {
      const env = validateEnv({ ...validEnv, NODE_ENV: nodeEnv });
      expect(env.S3_ENDPOINT).toBe('http://localhost:9000');
      expect(env.SMTP_HOST).toBe('localhost');
    }
  });
});
