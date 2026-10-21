import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { envSchema, validateEnv } from './env.schema';
import { PUBLISHED_DEVELOPMENT_SECRETS } from './published-secrets';

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

  it('S3_PRIVATE_BUCKET : un bucket à part, jamais celui des médias publics', () => {
    expect(validateEnv({ ...validEnv }).S3_PRIVATE_BUCKET).toBe('carlys-private');
    // Le même nom remettrait les photos de repas dans le bucket lisible sans
    // jeton : refusé partout, pas seulement en production.
    expect(() =>
      validateEnv({ ...validEnv, S3_BUCKET: 'carlys-media', S3_PRIVATE_BUCKET: 'carlys-media' }),
    ).toThrow(/S3_PRIVATE_BUCKET: doit différer de S3_BUCKET/);
    expect(() => validateEnv({ ...validEnv, S3_PRIVATE_BUCKET: 'Photos Privées' })).toThrow(
      /nom de bucket S3/,
    );
  });

  it('coach : le fournisseur est un réglage, absent = 503, jamais un refus de démarrer', () => {
    const minimal = validateEnv({ ...validEnv });
    // Rien de posé : l'API démarre, le coach est simplement indisponible.
    expect(minimal.COACH_API_BASE_URL).toBeUndefined();
    expect(minimal.COACH_API_KEY).toBeUndefined();
    expect(minimal.COACH_MODEL).toBeUndefined();

    const mistral = validateEnv({
      ...validEnv,
      COACH_API_BASE_URL: 'https://api.mistral.ai/v1',
      COACH_API_KEY: 'cle-factice-de-test',
      COACH_MODEL: 'mistral-small-latest',
    });
    expect(mistral.COACH_API_BASE_URL).toBe('https://api.mistral.ai/v1');
    expect(mistral.COACH_MODEL).toBe('mistral-small-latest');

    // Une adresse sans schéma, ou une variable présente mais VIDE : c'est une
    // faute de frappe, refusée dès la configuration (« optionnel » veut dire
    // absent, pas vide).
    expect(() => validateEnv({ ...validEnv, COACH_API_BASE_URL: 'api.mistral.ai/v1' })).toThrow(
      /COACH_API_BASE_URL/,
    );
    expect(() => validateEnv({ ...validEnv, COACH_API_KEY: '' })).toThrow(/COACH_API_KEY/);
    expect(() => validateEnv({ ...validEnv, COACH_MODEL: '' })).toThrow(/COACH_MODEL/);
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
    TRUST_PROXY_HOPS: '2',
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

  // Le coach envoie `Authorization: Bearer <clé>` et des données de santé à
  // cette adresse : en clair, une faute de frappe les ferait voyager lisibles.
  it('exige https:// pour COACH_API_BASE_URL hors du réseau compose, pas pour un Ollama interne sans clé', () => {
    const coach = { COACH_MODEL: 'mistral-small-latest', COACH_API_KEY: 'cle-factice-de-test' };
    expect(() =>
      validateEnv({ ...productionEnv, ...coach, COACH_API_BASE_URL: 'http://api.mistral.ai/v1' }),
    ).toThrow(/COACH_API_BASE_URL.*https/);
    expect(
      validateEnv({ ...productionEnv, ...coach, COACH_API_BASE_URL: 'https://api.mistral.ai/v1' })
        .COACH_API_BASE_URL,
    ).toBe('https://api.mistral.ai/v1');
    expect(
      validateEnv({
        ...productionEnv,
        COACH_MODEL: 'ministral-3:8b',
        COACH_API_BASE_URL: 'http://ollama:11434/v1',
      }).COACH_API_BASE_URL,
    ).toBe('http://ollama:11434/v1');
  });

  // La passerelle (ADR 0013) envoie la même clé et le même contexte à CHAQUE
  // worker : la règle vaut pour toute la liste, pas pour sa seule tête.
  it('exige https:// pour CHAQUE worker de COACH_WORKER_URLS hors du réseau compose', () => {
    const coach = {
      COACH_MODEL: 'qwen3:4b',
      COACH_API_KEY: 'cle-factice-de-test',
      COACH_API_BASE_URL: 'https://gpu-1.carlys.example/v1',
    };
    expect(() =>
      validateEnv({
        ...productionEnv,
        ...coach,
        COACH_WORKER_URLS: 'https://gpu-1.carlys.example/v1,http://gpu-2.interne:11434/v1',
      }),
    ).toThrow(/COACH_WORKER_URLS.*https/);
    expect(
      validateEnv({
        ...productionEnv,
        ...coach,
        COACH_WORKER_URLS: 'https://gpu-1.carlys.example/v1,https://gpu-2.carlys.example/v1',
      }).COACH_WORKER_URLS,
    ).toContain('gpu-2');
    // Sans clé, des Ollama internes au réseau compose restent permis.
    expect(
      validateEnv({
        ...productionEnv,
        COACH_MODEL: 'qwen3:4b',
        COACH_WORKER_URLS: 'http://ollama:11434/v1,http://ollama-2:11434/v1',
      }).COACH_WORKER_URLS,
    ).toContain('ollama-2');
  });

  // Règle d'infrastructure/server/config/commun.conf : un worker HORS du
  // réseau compose demande https:// ET COACH_API_KEY. Hors du réseau compose,
  // c'est tout ce qui n'est pas un nom de service : un hôte à point (domaine,
  // IPv4), une IPv6, ou localhost (dans le conteneur de l'API, c'est l'API).
  it('worker hors du réseau compose : https:// exigé, même sans clé', () => {
    for (const url of [
      'http://gpu-2.carlys.example:11434/v1',
      'http://10.0.0.5:11434/v1',
      'http://[fd00::5]:11434/v1',
      'http://localhost:11434/v1',
    ]) {
      expect(() =>
        validateEnv({ ...productionEnv, COACH_MODEL: 'qwen3:4b', COACH_WORKER_URLS: url }),
      ).toThrow(/COACH_WORKER_URLS.*https/);
    }
    expect(() =>
      validateEnv({
        ...productionEnv,
        COACH_MODEL: 'qwen3:4b',
        COACH_API_BASE_URL: 'http://127.0.0.1:11434/v1',
      }),
    ).toThrow(/COACH_API_BASE_URL.*https/);
  });

  it('worker hors du réseau compose : COACH_API_KEY exigée, même en https://', () => {
    expect(() =>
      validateEnv({
        ...productionEnv,
        COACH_MODEL: 'qwen3:4b',
        COACH_WORKER_URLS: 'http://ollama:11434/v1,https://gpu-2.carlys.example/v1',
      }),
    ).toThrow(/COACH_WORKER_URLS.*COACH_API_KEY/);
    expect(() =>
      validateEnv({
        ...productionEnv,
        COACH_MODEL: 'qwen3:4b',
        COACH_API_BASE_URL: 'https://gpu-1.carlys.example/v1',
      }),
    ).toThrow(/COACH_API_BASE_URL.*COACH_API_KEY/);
  });

  it('le mélange documenté (ollama interne + worker externe en https, clé posée) passe', () => {
    // L'exemple commenté de commun.conf, tel quel : la clé ne circule en
    // clair que sur le réseau compose, interne à la machine.
    expect(
      validateEnv({
        ...productionEnv,
        COACH_MODEL: 'qwen3:4b',
        COACH_API_KEY: 'cle-factice-de-test',
        COACH_API_BASE_URL: 'http://ollama:11434/v1',
        COACH_WORKER_URLS: 'http://ollama:11434/v1,https://gpu-2.carlys.example/v1',
      }).COACH_WORKER_URLS,
    ).toContain('gpu-2');
  });

  // La configuration VERSIONNÉE doit passer la garde : sinon c'est la
  // production qui refuserait de démarrer au prochain déploiement.
  it.each(['staging', 'production'])(
    'les réglages du coach de infrastructure/server/config (%s) passent',
    (name) => {
      const config = join(__dirname, '..', '..', '..', '..', 'infrastructure', 'server', 'config');
      const coach: Record<string, string> = {};
      for (const file of ['commun.conf', `${name}.conf`]) {
        const text = readFileSync(join(config, file), 'utf8');
        for (const [, key, value] of text.matchAll(/^(COACH_[A-Z_]+)=(.*)$/gm)) {
          coach[key!] = value!;
        }
      }
      expect(() => validateEnv({ ...productionEnv, ...coach })).not.toThrow();
    },
  );

  it('refuse un worker qui n’est pas en http(s)', () => {
    expect(() => validateEnv({ ...validEnv, COACH_WORKER_URLS: 'ftp://gpu.interne/v1' })).toThrow(
      /COACH_WORKER_URLS/,
    );
  });

  // CORS_ORIGINS est une LISTE : le contrôle doit voir chaque entrée, pas
  // seulement la première. Une garde qui n'inspecte qu'un élément sur trois
  // est pire qu'aucune — elle fait croire que quelqu'un a regardé.
  it('exige https:// pour CHAQUE origine de CORS_ORIGINS', () => {
    expect(() =>
      validateEnv({ ...productionEnv, CORS_ORIGINS: 'http://app.carlys.example' }),
    ).toThrow(/CORS_ORIGINS.*https/);

    // L'entrée fautive est en DEUXIÈME position : c'est le cas qu'un
    // `startsWith` sur la chaîne entière laisserait passer.
    expect(() =>
      validateEnv({
        ...productionEnv,
        CORS_ORIGINS: 'https://app.carlys.example,http://admin.carlys.example',
      }),
    ).toThrow(/CORS_ORIGINS.*https/);

    // Le message nomme l'origine fautive, pas seulement la variable : sans
    // cela, une liste de six origines laisse chercher laquelle est en cause.
    expect(() =>
      validateEnv({
        ...productionEnv,
        CORS_ORIGINS: 'https://app.carlys.example,http://admin.carlys.example',
      }),
    ).toThrow(/http:\/\/admin\.carlys\.example/);

    // Plusieurs origines toutes en https, espaces compris : acceptées.
    expect(
      validateEnv({
        ...productionEnv,
        CORS_ORIGINS: 'https://app.carlys.example, https://admin.carlys.example',
      }).CORS_ORIGINS,
    ).toBe('https://app.carlys.example, https://admin.carlys.example');
  });

  it('refuse les identifiants de développement carlys-dev*', () => {
    expect(() => validateEnv({ ...productionEnv, S3_ACCESS_KEY_ID: 'carlys-dev-autre' })).toThrow(
      /S3_ACCESS_KEY_ID.*carlys-dev/,
    );
    expect(() =>
      validateEnv({ ...productionEnv, S3_SECRET_ACCESS_KEY: 'carlys-dev-secret-2' }),
    ).toThrow(/S3_SECRET_ACCESS_KEY.*carlys-dev/);
  });

  it('exige TRUST_PROXY_HOPS ≥ 1 : derrière Nginx, 0 confondrait tous les clients', () => {
    expect(() => validateEnv({ ...productionEnv, TRUST_PROXY_HOPS: '0' })).toThrow(
      /TRUST_PROXY_HOPS/,
    );
  });

  it('SMTP_SECURE=false reste faux (z.coerce.boolean le lisait vrai)', () => {
    expect(validateEnv({ ...validEnv, SMTP_SECURE: 'false' }).SMTP_SECURE).toBe(false);
    expect(validateEnv({ ...validEnv, SMTP_SECURE: 'true' }).SMTP_SECURE).toBe(true);
  });

  it('refuse un gabarit CHANGE_MOI_ resté en place, secret JWT en tête', () => {
    expect(() =>
      validateEnv({
        ...productionEnv,
        JWT_ACCESS_SECRET: 'CHANGE_MOI_SECRET_JWT_PRODUCTION_OPENSSL_RAND_HEX_32',
      }),
    ).toThrow(/JWT_ACCESS_SECRET.*gabarit/);
    expect(() =>
      validateEnv({ ...productionEnv, METRICS_TOKEN: 'CHANGE_MOI_JETON_METRIQUES' }),
    ).toThrow(/METRICS_TOKEN.*gabarit/);
  });

  // Le gabarit `CHANGE_MOI_` n'est pas la seule valeur publiée : les exemples
  // de développement (apps/api/.env.example, .env.example, docker-compose.yml)
  // en portent d'autres, assez longues pour passer Zod. Avec celle du secret
  // JWT, n'importe qui forge une session à n'importe quel compte.
  it('refuse toute valeur de secret publiée dans le dépôt, JWT et empreintes en tête', () => {
    expect(() =>
      validateEnv({
        ...productionEnv,
        JWT_ACCESS_SECRET: 'secret-jwt-de-developpement-a-remplacer-absolument',
      }),
    ).toThrow(/JWT_ACCESS_SECRET.*publiée/);
    expect(() =>
      validateEnv({
        ...productionEnv,
        LOG_FINGERPRINT_SECRET: 'cle-empreintes-de-developpement-a-remplacer',
      }),
    ).toThrow(/LOG_FINGERPRINT_SECRET.*publiée/);
    expect(() =>
      validateEnv({
        ...productionEnv,
        STRIPE_SECRET_KEY: 'sk_test_valeur_factice_de_developpement',
      }),
    ).toThrow(/STRIPE_SECRET_KEY.*publiée/);
    // Le mot de passe PostgreSQL publié, recopié dans l'URL de connexion.
    expect(() =>
      validateEnv({
        ...productionEnv,
        DATABASE_URL: 'postgresql://carlys:carlys_dev_password@localhost:5432/carlys_dev',
      }),
    ).toThrow(/DATABASE_URL.*publiée/);
  });

  // Les secrets d'un fichier .env d'exemple, lignes commentées comprises. La
  // valeur s'arrête au premier blanc ou guillemet : un commentaire en fin de
  // ligne, une espace de trop ou des guillemets ne la cachent pas.
  const secret = /(SECRET|PASSWORD|TOKEN|_KEY)$/;
  function exampleSecrets(text: string): Map<string, string> {
    const found = new Map<string, string>();
    for (const [, key, value] of text.matchAll(
      /^#?[ \t]*(?:export[ \t]+)?([A-Z_][A-Z0-9_]*)[ \t]*=[ \t]*["']?([^\s"']+)/gm,
    )) {
      if (secret.test(key!) && !value!.includes('CHANGE_MOI')) found.set(key!, value!);
    }
    return found;
  }

  it('la lecture des exemples voit une valeur suivie d’un commentaire, d’espaces ou entre guillemets', () => {
    const found = exampleSecrets(
      [
        'JWT_ACCESS_SECRET=valeur-un   # à remplacer',
        '# STRIPE_SECRET_KEY=valeur-deux ',
        'export METRICS_TOKEN = "valeur-trois"',
        'COACH_API_KEY=',
        'LOG_LEVEL=debug',
      ].join('\n'),
    );
    expect([...found]).toEqual([
      ['JWT_ACCESS_SECRET', 'valeur-un'],
      ['STRIPE_SECRET_KEY', 'valeur-deux'],
      ['METRICS_TOKEN', 'valeur-trois'],
    ]);
  });

  // La liste se tient seule : chaque secret que les exemples publient doit y
  // être. Une valeur changée dans un exemple sans la liste fait échouer ici.
  it('chaque secret publié par un exemple du dépôt figure dans la liste de refus', () => {
    const root = join(__dirname, '..', '..', '..', '..');
    const read = (path: string) => readFileSync(join(root, path), 'utf8');
    const published = new Map<string, string>([
      ...exampleSecrets(read('apps/api/.env.example')),
      ...exampleSecrets(read('.env.example')),
    ]);
    for (const [, key, value] of read('docker-compose.yml').matchAll(
      /\$\{([A-Z_][A-Z0-9_]*):-([^}]+)\}/g,
    )) {
      if (secret.test(key!)) published.set(key!, value!);
    }
    // Garde du garde : la lecture trouve bien les secrets annoncés.
    expect(published.get('JWT_ACCESS_SECRET')).toBe(
      'secret-jwt-de-developpement-a-remplacer-absolument',
    );
    expect(published.has('LOG_FINGERPRINT_SECRET')).toBe(true);
    expect(published.has('POSTGRES_PASSWORD')).toBe(true);
    const missing = [...published].filter(
      ([, value]) => !PUBLISHED_DEVELOPMENT_SECRETS.includes(value),
    );
    expect(missing).toEqual([]);
  });

  it('hors production, les défauts de développement restent acceptés', () => {
    for (const nodeEnv of ['development', 'test', 'staging']) {
      const env = validateEnv({ ...validEnv, NODE_ENV: nodeEnv });
      expect(env.S3_ENDPOINT).toBe('http://localhost:9000');
      expect(env.SMTP_HOST).toBe('localhost');
    }
  });
});

/**
 * Le tableau « apps/api/.env » du README est ce qu'on lit pour configurer
 * l'API. Il ne décrit pas tout (les fournisseurs ont leur guide), mais il
 * présente le STOCKAGE OBJET comme complet : une variable S3 ajoutée au
 * schéma sans sa ligne (`S3_PRIVATE_BUCKET`, le second bucket, privé)
 * laissait ignorer qu'un bucket de plus doit exister.
 */
describe('README.md, tableau de apps/api/.env', () => {
  it('décrit chaque variable S3 du schéma', () => {
    const readme = readFileSync(join(__dirname, '..', '..', '..', '..', 'README.md'), 'utf8');
    const s3 = Object.keys(envSchema.shape).filter((key) => key.startsWith('S3_'));
    expect(s3.length).toBeGreaterThan(0);
    expect(s3.filter((key) => !readme.includes(`\`${key}\``))).toEqual([]);
  });
});
