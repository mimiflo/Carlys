process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type ApiErrorEnvelope } from '@carlys/api-contracts';
import { REQUEST_ID_HEADER } from '@carlys/shared-config';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { request as httpRequest, type Server } from 'node:http';
import { type AddressInfo } from 'node:net';
import { gzipSync } from 'node:zlib';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';

interface RawResponse {
  status: number;
  headers: Record<string, string | string[] | undefined>;
  error: ApiErrorEnvelope['error'];
}

/**
 * Corps de requête refusés AVANT le routage : un statut 4xx juste (et non un
 * 500 « Exception non gérée »), et un requestId qui permet de retrouver la
 * requête dans les journaux.
 *
 * L'application est créée EXACTEMENT comme les autres suites — sans
 * reproduire main.ts à la main : les parseurs de corps vivent désormais dans
 * `configureApp`, et cette suite le vérifie (limite de 1 Mo, pas les 100 Ko
 * du parseur par défaut de Nest).
 *
 * Les corps partent par `node:http` brut et non par supertest : superagent
 * sérialise en JSON un Buffer envoyé sous `Content-Type: application/json`,
 * ce qui détruirait le gzip avant qu'il n'atteigne le serveur.
 */
describe('Corps de requête : limites, encodages, corrélation (e2e)', () => {
  let app: INestApplication<App>;
  let port: number;

  const post = (
    path: string,
    body: Buffer | string,
    headers: Record<string, string> = {},
  ): Promise<RawResponse> =>
    new Promise((resolve, reject) => {
      const payload = typeof body === 'string' ? Buffer.from(body) : body;
      const req = httpRequest(
        {
          host: '127.0.0.1',
          port,
          path,
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'content-length': String(payload.length),
            ...headers,
          },
        },
        (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer) => chunks.push(chunk));
          res.on('end', () => {
            const parsed = JSON.parse(Buffer.concat(chunks).toString('utf8')) as ApiErrorEnvelope;
            resolve({ status: res.statusCode ?? 0, headers: res.headers, error: parsed.error });
          });
        },
      );
      req.on('error', reject);
      req.end(payload);
    });

  /** L'erreur porte un vrai requestId, le même que l'en-tête de la réponse. */
  const expectCorrelated = (res: RawResponse): void => {
    expect(res.error.requestId).not.toBe('unknown');
    expect(res.headers[REQUEST_ID_HEADER]).toBe(res.error.requestId);
  };
  const jsonOfSize = (bytes: number): string =>
    JSON.stringify({
      email: 'x@carlys.test',
      password: 'MotDePasse42',
      bourrage: 'a'.repeat(bytes),
    });

  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    const server = app.getHttpServer() as unknown as Server;
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    port = (server.address() as AddressInfo).port;
  });

  afterAll(async () => {
    await app.close();
  });

  it('un gzip de quelques Ko qui gonfle à 2 Mo : 413, pas 500, et corrélé', async () => {
    const bombe = gzipSync(Buffer.from(jsonOfSize(2 * 1024 * 1024)));
    expect(bombe.length).toBeLessThan(10_000);
    const res = await post('/api/v1/auth/login', bombe, { 'content-encoding': 'gzip' });
    expect(res.status).toBe(413);
    expect(res.error.code).toBe('PAYLOAD_TOO_LARGE');
    expectCorrelated(res);
  });

  it('un JSON de 1,5 Mo : 413 ; sur les webhooks aussi (parseur brut)', async () => {
    const json = await post('/api/v1/auth/login', jsonOfSize(1_500_000));
    expect(json.status).toBe(413);
    expectCorrelated(json);

    const webhook = await post('/api/v1/webhooks/stripe', jsonOfSize(1_100_000));
    expect(webhook.status).toBe(413);
    expect(webhook.error.code).toBe('PAYLOAD_TOO_LARGE');
  });

  it('gzip corrompu : 400 ; encodage inconnu : 415', async () => {
    const corrompu = await post('/api/v1/auth/login', Buffer.from('ceci n’est pas du gzip'), {
      'content-encoding': 'gzip',
    });
    expect(corrompu.status).toBe(400);
    expect(corrompu.error.code).toBe('BAD_REQUEST');
    expectCorrelated(corrompu);

    const inconnu = await post('/api/v1/auth/login', '{}', { 'content-encoding': 'compress' });
    expect(inconnu.status).toBe(415);
    expect(inconnu.error.code).toBe('UNSUPPORTED_MEDIA_TYPE');
  });

  it('JSON malformé : 400 corrélé, et l’en-tête x-request-id entrant est repris', async () => {
    const res = await post('/api/v1/auth/login', '{"email": "x",', {
      [REQUEST_ID_HEADER]: 'essai-correlation-42',
    });
    expect(res.status).toBe(400);
    expect(res.error.requestId).toBe('essai-correlation-42');
    expect(res.headers[REQUEST_ID_HEADER]).toBe('essai-correlation-42');
  });

  it('un corps légitime entre 100 Ko et 1 Mo passe le parseur, comme en production', async () => {
    // 300 Ko : au-delà du parseur par défaut de Nest (100 Ko), sous la
    // limite de production (1 Mo). Il atteint la validation — qui refuse le
    // champ inconnu —, et non plus un 413 du parseur.
    const res = await post('/api/v1/auth/login', jsonOfSize(300_000));
    expect(res.status).toBe(400);
    expect(res.error.code).toBe('VALIDATION_ERROR');
    expectCorrelated(res);
  });
});
